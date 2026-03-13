import Flutter
import UIKit
import AVFoundation

public class CameraPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "zootocam/camera",
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private let registrar: FlutterPluginRegistrar
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    private var textureId: Int64 = -1

    // Thread-safe pixel buffer
    private let bufferLock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?

    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var photoCaptureCompletion: ((String?) -> Void)?
    private var currentSavePath: String?

    // Dedicated serial queue for video frames
    private let videoQueue = DispatchQueue(
        label: "zootocam.video",
        qos: .userInteractive
    )

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeCamera":
            initializeCamera(result: result)
        case "startCamera":
            captureSession?.startRunning()
            result(nil)
        case "stopCamera":
            stopCamera(result: result)
        case "takePicture":
            takePicture(call: call, result: result)
        case "setFlash":
            setFlash(call: call, result: result)
        case "setFocusPoint":
            setFocusPoint(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize

    private func initializeCamera(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Prefer dual-wide camera, fall back to wide angle
            let device = AVCaptureDevice.default(
                .builtInDualWideCamera,
                for: .video,
                position: .back
            ) ?? AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )

            guard let device = device else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "NO_CAMERA",
                        message: "カメラが見つかりません",
                        details: nil
                    ))
                }
                return
            }

            self.currentDevice = device

            do {
                // Continuous AF / AE / AWB
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                device.unlockForConfiguration()

                let session = AVCaptureSession()
                session.beginConfiguration()

                // Use hd1920x1080 for better preview; photo capture overrides automatically
                if session.canSetSessionPreset(.hd1920x1080) {
                    session.sessionPreset = .hd1920x1080
                } else {
                    session.sessionPreset = .photo
                }

                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                // Photo output
                let photoOutput = AVCapturePhotoOutput()
                photoOutput.isHighResolutionCaptureEnabled = true
                if #available(iOS 16.0, *) {
                    photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last
                        ?? photoOutput.maxPhotoDimensions
                }
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    self.photoOutput = photoOutput
                }

                // Video output for texture preview
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                    self.videoOutput = videoOutput

                    // Orientation
                    if let connection = videoOutput.connection(with: .video) {
                        let orientation = self.currentVideoOrientation()
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = orientation
                        }
                        // Stabilization
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                }

                session.commitConfiguration()
                self.captureSession = session

                // Register texture
                let textureId = self.registrar.textures().register(self)
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

    // MARK: - Stop

    private func stopCamera(result: @escaping FlutterResult) {
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.photoOutput = nil
            self.videoOutput = nil
            self.currentDevice = nil

            self.bufferLock.lock()
            self.latestPixelBuffer = nil
            self.bufferLock.unlock()

            DispatchQueue.main.async {
                if self.textureId >= 0 {
                    self.registrar.textures().unregisterTexture(self.textureId)
                    self.textureId = -1
                }
                result(nil)
            }
        }
    }

    // MARK: - Take Picture

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
            if let path = path {
                result(path)
            } else {
                result(FlutterError(code: "CAPTURE_FAILED", message: "撮影に失敗しました", details: nil))
            }
        }

        var settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc),
           let hevcSettings = AVCapturePhotoSettings(
               format: [AVVideoCodecKey: AVVideoCodecType.hevc]
           ) as AVCapturePhotoSettings? {
            settings = hevcSettings
        } else {
            settings = AVCapturePhotoSettings()
        }

        settings.flashMode = flashMode
        settings.isHighResolutionPhotoEnabled = true

        // Set orientation for capture connection
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation()
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Flash

    private func setFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(nil)
            return
        }
        flashMode = enabled ? .on : .off
        result(nil)
    }

    // MARK: - Tap to Focus / Expose

    private func setFocusPoint(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "x, y が必要です", details: nil))
            return
        }

        guard let device = currentDevice else {
            result(nil)
            return
        }

        let point = CGPoint(x: x, y: y)

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported &&
               device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported &&
               device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            result(nil)
        } catch {
            result(FlutterError(code: "FOCUS_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Orientation Helper

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraPlugin: AVCapturePhotoCaptureDelegate {

    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            photoCaptureCompletion = nil
            currentSavePath = nil
        }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let savePath = currentSavePath else {
            photoCaptureCompletion?(nil)
            return
        }

        do {
            let url = URL(fileURLWithPath: savePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            photoCaptureCompletion?(savePath)
        } catch {
            photoCaptureCompletion?(nil)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        bufferLock.lock()
        latestPixelBuffer = imageBuffer
        bufferLock.unlock()

        if textureId >= 0 {
            registrar.textures().textureFrameAvailable(textureId)
        }
    }
}

// MARK: - FlutterTexture

extension CameraPlugin: FlutterTexture {

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard let buffer = latestPixelBuffer else { return nil }
        return .passRetained(buffer)
    }
}
