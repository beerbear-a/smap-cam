import Flutter
import UIKit
import AVFoundation

public class CameraPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "smap.cam/camera",
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private let registrar: FlutterPluginRegistrar
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var textureRegistry: FlutterTextureRegistry?
    private var pixelBuffer: CVPixelBuffer?
    private var textureId: Int64 = -1
    private var videoOutput: AVCaptureVideoDataOutput?
    private var flashMode: AVCaptureDevice.FlashMode = .off

    // Completion handler for photo capture
    private var photoCaptureCompletion: ((String?) -> Void)?
    private var currentSavePath: String?

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        self.textureRegistry = registrar.textures()
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeCamera":
            initializeCamera(result: result)
        case "startCamera":
            startCamera(call: call, result: result)
        case "stopCamera":
            stopCamera(result: result)
        case "takePicture":
            takePicture(call: call, result: result)
        case "setFlash":
            setFlash(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeCamera(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "NO_CAMERA",
                        message: "カメラが見つかりません",
                        details: nil
                    ))
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                let photoOutput = AVCapturePhotoOutput()
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    self.photoOutput = photoOutput
                }

                // Video output for texture preview
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_32BGRA
                ]
                videoOutput.setSampleBufferDelegate(
                    self,
                    queue: DispatchQueue(label: "smap.cam.video")
                )
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                    self.videoOutput = videoOutput
                }

                self.captureSession = session

                let textureId = self.textureRegistry?.register(self) ?? -1
                self.textureId = textureId

                session.startRunning()

                DispatchQueue.main.async {
                    result(["textureId": textureId])
                }

            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CAMERA_INIT_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func startCamera(call: FlutterMethodCall, result: @escaping FlutterResult) {
        captureSession?.startRunning()
        result(nil)
    }

    private func stopCamera(result: @escaping FlutterResult) {
        captureSession?.stopRunning()
        if textureId >= 0 {
            textureRegistry?.unregisterTexture(textureId)
            textureId = -1
        }
        captureSession = nil
        photoOutput = nil
        result(nil)
    }

    private func takePicture(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let savePath = args["savePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "保存パスが必要です", details: nil))
            return
        }

        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NOT_READY", message: "カメラが準備できていません", details: nil))
            return
        }

        self.currentSavePath = savePath
        self.photoCaptureCompletion = { path in
            result(path ?? FlutterError(code: "CAPTURE_FAILED", message: "撮影失敗", details: nil))
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func setFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterMethodNotImplemented)
            return
        }
        flashMode = enabled ? .on : .off
        result(nil)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraPlugin: AVCapturePhotoCaptureDelegate {

    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let savePath = currentSavePath else {
            photoCaptureCompletion?(nil)
            photoCaptureCompletion = nil
            return
        }

        do {
            try data.write(to: URL(fileURLWithPath: savePath))
            photoCaptureCompletion?(savePath)
        } catch {
            photoCaptureCompletion?(nil)
        }

        photoCaptureCompletion = nil
        currentSavePath = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        if textureId >= 0 {
            textureRegistry?.textureFrameAvailable(textureId)
        }
    }
}

// MARK: - FlutterTexture
extension CameraPlugin: FlutterTexture {

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return .passRetained(buffer)
    }
}
