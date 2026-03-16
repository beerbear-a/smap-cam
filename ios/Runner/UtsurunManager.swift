import AVFoundation
import CoreImage

/// 「写ルンです」の制約をデジタルで再現するための設定ユーティリティ。
/// - 32mm相当の画角（広角レンズをクロップ）
/// - パンフォーカス（固定焦点）
/// - 露出バイアスで「明るく飛ぶ」質感
/// - 低解像 + 周辺減光の例
final class UtsurunManager {
    struct ExposureProfile {
        let targetBias: Float
    }

    static let defaultExposure = ExposureProfile(targetBias: 1.0)

    /// 32mm相当の画角に合わせたズーム係数を返す。
    /// 広角（24〜26mm相当）を32mmへクロップする想定。
    static func zoomFactorFor32mm(device: AVCaptureDevice) -> CGFloat {
        let baseEquivalent = baseEquivalentFocalLength(device: device)
        let ratio = CGFloat(32.0 / baseEquivalent)
        let minZoom = max(device.minAvailableVideoZoomFactor, device.activeFormat.videoMinZoomFactor)
        let maxZoom = device.maxAvailableVideoZoomFactor
        return min(max(ratio, minZoom), maxZoom)
    }

    /// パンフォーカス（固定焦点）設定。
    static func applyFixedFocus(to device: AVCaptureDevice, lensPosition: Float = 0.6) {
        guard device.isFocusModeSupported(.locked) else { return }
        device.focusMode = .locked
        device.setFocusModeLocked(lensPosition: lensPosition, completionHandler: nil)
    }

    /// 露出プロファイル: 明るく飛びやすい質感を残すためのバイアス。
    static func applyExposureProfile(to device: AVCaptureDevice,
                                     profile: ExposureProfile = defaultExposure) {
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        let clamped = max(device.minExposureTargetBias,
                          min(profile.targetBias, device.maxExposureTargetBias))
        device.setExposureTargetBias(clamped, completionHandler: nil)
    }

    /// 周辺光量落ちのサンプル（CMSampleBuffer → CIImage）。
    /// 実際の書き込みは呼び出し側で行う。
    static func applyVignette(to sampleBuffer: CMSampleBuffer,
                              intensity: Double = 0.9,
                              radius: Double = 1.2) -> CIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        let inputImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let filter = CIFilter(name: "CIVignette") else { return inputImage }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        return filter.outputImage ?? inputImage
    }

    // MARK: - Helpers

    private static func baseEquivalentFocalLength(device: AVCaptureDevice) -> Double {
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return 13.0
        case .builtInWideAngleCamera, .builtInDualWideCamera, .builtInTripleCamera:
            return 24.0
        case .builtInTelephotoCamera:
            return 52.0
        default:
            return 24.0
        }
    }
}
