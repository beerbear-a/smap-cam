import Flutter
import UIKit
import AVFoundation
import Vision
import MediaPlayer

public class CameraPlugin: NSObject, FlutterPlugin {

    private enum FocalPreset: String {
        case f13
        case f24
        case f35
        case f48
        case f120

        var zoomFactor: CGFloat {
            switch self {
            case .f13:
                return 1.0
            case .f24:
                return 1.0
            case .f35:
                return 1.5
            case .f48:
                return 2.0
            case .f120:
                return 1.0
            }
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "zootocam/camera",
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraPlugin(registrar: registrar, channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private let registrar: FlutterPluginRegistrar
    private let channel: FlutterMethodChannel
    private var captureSession: AVCaptureSession?
    private var currentInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    private var textureId: Int64 = -1
    private var utsurunEnabled: Bool = false

    // Thread-safe pixel buffer
    private let bufferLock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?

    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var photoCaptureCompletion: ((String?) -> Void)?
    private var currentSavePath: String?

    private var volumeView: MPVolumeView?
    private var volumeObserver: NSKeyValueObservation?
    private var lastVolume: Float = 0.5
    private var lastHardwareTrigger = Date.distantPast
    private var ignoreNextVolumeEvent = false

    // Dedicated serial queue for video frames
    private let videoQueue = DispatchQueue(
        label: "zootocam.video",
        qos: .userInteractive
    )
    private let sessionQueue = DispatchQueue(
        label: "zootocam.camera.session",
        qos: .userInitiated
    )

    init(registrar: FlutterPluginRegistrar, channel: FlutterMethodChannel) {
        self.registrar = registrar
        self.channel = channel
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
        case "setFocalLength":
            setFocalLength(call: call, result: result)
        case "setUtsurunEnabled":
            setUtsurunEnabled(call: call, result: result)
        case "classifyImage":
            classifyImage(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize

    private func initializeCamera(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let device = self.bestDevice(for: .f35)

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
                let session = AVCaptureSession()
                session.beginConfiguration()

                // Favor lower-latency preview on device; photo capture quality is controlled separately.
                if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                } else if session.canSetSessionPreset(.vga640x480) {
                    session.sessionPreset = .vga640x480
                } else {
                    session.sessionPreset = .photo
                }

                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.currentInput = input
                }

                // Photo output
                let photoOutput = AVCapturePhotoOutput()
                photoOutput.isHighResolutionCaptureEnabled = !self.utsurunEnabled
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
                        // Preview stabilization adds visible latency on device.
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .off
                        }
                    }
                }

                session.commitConfiguration()
                self.captureSession = session
                try self.applyDefaultConfiguration(to: device, preset: .f35)

                // Register texture
                let textureId = self.registrar.textures().register(self)
                self.textureId = textureId

                session.startRunning()
                self.startHardwareShutterListening()

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
            self.stopHardwareShutterListening()
            self.captureSession = nil
            self.currentInput = nil
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

    // MARK: - Hardware Shutter (Volume Buttons)

    private func startHardwareShutterListening() {
        guard volumeObserver == nil else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
        } catch {
            // If audio session activation fails, we skip hardware shutter.
        }

        lastVolume = audioSession.outputVolume
        ignoreNextVolumeEvent = true

        let volumeView = MPVolumeView(frame: .zero)
        volumeView.isHidden = true
        volumeView.alpha = 0.01
        if let hostView = registrar.viewController?.view {
            hostView.addSubview(volumeView)
        }
        self.volumeView = volumeView

        volumeObserver = audioSession.observe(
            \.outputVolume,
            options: [.new, .old]
        ) { [weak self] session, change in
            guard let self = self else { return }
            let newVolume = change.newValue ?? session.outputVolume
            self.handleVolumeChange(newVolume: newVolume)
        }
    }

    private func stopHardwareShutterListening() {
        volumeObserver?.invalidate()
        volumeObserver = nil
        volumeView?.removeFromSuperview()
        volumeView = nil
    }

    private func handleVolumeChange(newVolume: Float) {
        if ignoreNextVolumeEvent {
            ignoreNextVolumeEvent = false
            lastVolume = newVolume
            return
        }
        guard captureSession?.isRunning == true else { return }
        let now = Date()
        if now.timeIntervalSince(lastHardwareTrigger) < 0.35 {
            lastVolume = newVolume
            return
        }
        if abs(newVolume - lastVolume) < 0.001 {
            return
        }
        lastVolume = newVolume
        lastHardwareTrigger = now

        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("hardwareShutter", arguments: nil)
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
        settings.isHighResolutionPhotoEnabled = !utsurunEnabled

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

    // MARK: - Focal Length

    private func setFocalLength(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let focalLength = args["focalLength"] as? String,
              let preset = FocalPreset(rawValue: focalLength) else {
            result(FlutterError(code: "INVALID_ARGS", message: "focalLength が必要です", details: nil))
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.applyFocalPreset(preset)
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FOCAL_LENGTH_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Utsurun Mode

    private func setUtsurunEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(nil)
            return
        }
        utsurunEnabled = enabled
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let output = self.photoOutput {
                output.isHighResolutionCaptureEnabled = !enabled
            }
            if let device = self.currentDevice {
                do {
                    try device.lockForConfiguration()
                    if enabled {
                        UtsurunManager.applyFixedFocus(to: device, lensPosition: 0.6)
                        UtsurunManager.applyExposureProfile(to: device, profile: .defaultExposure)
                        let zoomFactor = UtsurunManager.zoomFactorFor32mm(device: device)
                        if abs(device.videoZoomFactor - zoomFactor) > 0.01 {
                            device.ramp(toVideoZoomFactor: zoomFactor, withRate: 18.0)
                        } else {
                            device.videoZoomFactor = zoomFactor
                        }
                    } else {
                        if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        }
                        if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                        }
                    }
                    device.unlockForConfiguration()
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "UTSURUN_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    }
                    return
                }
            }
            DispatchQueue.main.async { result(nil) }
        }
    }

    // MARK: - Vision (Image Classification)

    private func classifyImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "imagePath が必要です", details: nil))
            return
        }

        let maxResults = (args["maxResults"] as? Int) ?? 3

        guard let image = UIImage(contentsOfFile: imagePath)?.cgImage else {
            result(FlutterError(code: "INVALID_IMAGE", message: "画像の読み込みに失敗しました", details: nil))
            return
        }

        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            let labels = observations.prefix(maxResults).map { $0.identifier }
            result(labels)
        }
        request.usesCPUOnly = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func applyFocalPreset(_ preset: FocalPreset) throws {
        guard let session = captureSession else {
            throw NSError(
                domain: "CameraPlugin",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "カメラが準備できていません"]
            )
        }

        let targetDevice = bestDevice(for: preset) ?? currentDevice
        guard let targetDevice = targetDevice else {
            throw NSError(
                domain: "CameraPlugin",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "対象レンズが見つかりません"]
            )
        }

        if currentDevice?.uniqueID != targetDevice.uniqueID {
            let newInput = try AVCaptureDeviceInput(device: targetDevice)
            session.beginConfiguration()
            if let currentInput = currentInput {
                session.removeInput(currentInput)
            }
            guard session.canAddInput(newInput) else {
                if let currentInput = currentInput, session.canAddInput(currentInput) {
                    session.addInput(currentInput)
                }
                session.commitConfiguration()
                throw NSError(
                    domain: "CameraPlugin",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "レンズ切り替えに失敗しました"]
                )
            }
            session.addInput(newInput)
            currentInput = newInput
            currentDevice = targetDevice

                if let connection = videoOutput?.connection(with: .video) {
                    let orientation = currentVideoOrientation()
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = orientation
                    }
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .off
                    }
                }
            session.commitConfiguration()
        }

        try applyDefaultConfiguration(to: targetDevice, preset: preset)
    }

    private func applyDefaultConfiguration(
        to device: AVCaptureDevice,
        preset: FocalPreset
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if utsurunEnabled {
            UtsurunManager.applyFixedFocus(to: device, lensPosition: 0.6)
            UtsurunManager.applyExposureProfile(to: device, profile: .defaultExposure)
        } else {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }

        device.cancelVideoZoomRamp()
        let zoomFactor = utsurunEnabled
            ? UtsurunManager.zoomFactorFor32mm(device: device)
            : max(
                device.minAvailableVideoZoomFactor,
                min(preset.zoomFactor, device.maxAvailableVideoZoomFactor)
            )
        if abs(device.videoZoomFactor - zoomFactor) > 0.01 {
            device.ramp(toVideoZoomFactor: zoomFactor, withRate: 18.0)
        } else {
            device.videoZoomFactor = zoomFactor
        }
    }

    private func bestDevice(for preset: FocalPreset) -> AVCaptureDevice? {
        switch preset {
        case .f13:
            return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .f120:
            return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .f24, .f35, .f48:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
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
