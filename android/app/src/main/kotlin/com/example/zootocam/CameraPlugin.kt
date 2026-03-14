package com.example.zootocam

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class CameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activityBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var preview: Preview? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var flashEnabled: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "zootocam/camera")
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
            "setFocusPoint" -> setFocusPoint(call, result)
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
                camera = cameraProvider?.bindToLifecycle(
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
                    fixExifRotation(savePath)
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

    /**
     * Exif 回転バグ修正:
     * CameraX は JPEG を保存する際、ピクセルを回転せず Exif の Orientation タグだけを
     * 設定する。Flutter の Image.file() は Exif を無視するため縦撮りが横向きになる。
     * → Exif の向きを読んでビットマップを実際に回転し、タグを NORMAL にリセットする。
     */
    private fun fixExifRotation(path: String) {
        try {
            val exif = ExifInterface(path)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            val degrees = when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90  -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> return // 回転不要
            }

            val bitmap = BitmapFactory.decodeFile(path) ?: return
            val matrix = Matrix().apply { postRotate(degrees) }
            val rotated = Bitmap.createBitmap(
                bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
            )
            bitmap.recycle()

            FileOutputStream(path).use { out ->
                rotated.compress(Bitmap.CompressFormat.JPEG, 95, out)
            }
            rotated.recycle()

            // Orientation タグを正常値にリセット
            exif.setAttribute(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL.toString()
            )
            exif.saveAttributes()
        } catch (_: Exception) {
            // 回転修正に失敗しても元ファイルは有効なので握りつぶす
        }
    }

    private fun setFocusPoint(call: MethodCall, result: MethodChannel.Result) {
        val x = (call.argument<Double>("x") ?: 0.5).toFloat()
        val y = (call.argument<Double>("y") ?: 0.5).toFloat()

        val camera = this.camera ?: run {
            result.error("NOT_READY", "Camera not initialized", null)
            return
        }

        val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
        val point = factory.createPoint(x, y)
        val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AF)
            .setAutoCancelDuration(5, TimeUnit.SECONDS)
            .build()
        camera.cameraControl.startFocusAndMetering(action)
        result.success(null)
    }
}
