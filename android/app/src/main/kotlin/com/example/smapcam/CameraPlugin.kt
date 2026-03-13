package com.example.smapcam

import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activityBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var preview: Preview? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var flashEnabled: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "smap.cam/camera")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutterPluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeCamera" -> initializeCamera(result)
            "startCamera" -> result.success(null)
            "stopCamera" -> stopCamera(result)
            "takePicture" -> takePicture(call, result)
            "setFlash" -> setFlash(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initializeCamera(result: MethodChannel.Result) {
        val activity = activityBinding?.activity ?: run {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        val binding = flutterPluginBinding ?: run {
            result.error("NO_BINDING", "Plugin not attached", null)
            return
        }

        val textureEntry = binding.textureRegistry.createSurfaceTexture()
        surfaceTextureEntry = textureEntry
        val textureId = textureEntry.id()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            val surfaceProvider = Preview.SurfaceProvider { request ->
                val texture = textureEntry.surfaceTexture()
                texture.setDefaultBufferSize(
                    request.resolution.width,
                    request.resolution.height
                )
                val surface = android.view.Surface(texture)
                request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {}
            }

            preview = Preview.Builder().build().also {
                it.setSurfaceProvider(surfaceProvider)
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setFlashMode(if (flashEnabled) ImageCapture.FLASH_MODE_ON else ImageCapture.FLASH_MODE_OFF)
                .build()

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageCapture
                )
                result.success(mapOf("textureId" to textureId))
            } catch (e: Exception) {
                result.error("CAMERA_INIT_ERROR", e.message, null)
            }

        }, ContextCompat.getMainExecutor(context))
    }

    private fun stopCamera(result: MethodChannel.Result) {
        cameraProvider?.unbindAll()
        surfaceTextureEntry?.release()
        surfaceTextureEntry = null
        cameraExecutor.shutdown()
        result.success(null)
    }

    private fun takePicture(call: MethodCall, result: MethodChannel.Result) {
        val savePath = call.argument<String>("savePath") ?: run {
            result.error("INVALID_ARGS", "savePath is required", null)
            return
        }

        val imageCapture = this.imageCapture ?: run {
            result.error("NOT_READY", "Camera not initialized", null)
            return
        }

        val outputFile = File(savePath)
        outputFile.parentFile?.mkdirs()

        val outputOptions = ImageCapture.OutputFileOptions.Builder(outputFile).build()

        imageCapture.takePicture(
            outputOptions,
            cameraExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    result.success(savePath)
                }

                override fun onError(exception: ImageCaptureException) {
                    result.error("CAPTURE_FAILED", exception.message, null)
                }
            }
        )
    }

    private fun setFlash(call: MethodCall, result: MethodChannel.Result) {
        flashEnabled = call.argument<Boolean>("enabled") ?: false
        imageCapture?.flashMode = if (flashEnabled)
            ImageCapture.FLASH_MODE_ON
        else
            ImageCapture.FLASH_MODE_OFF
        result.success(null)
    }
}
