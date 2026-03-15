import Flutter
import Photos
import UIKit

final class PhotoLibraryPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "zootocam/photo_library",
            binaryMessenger: registrar.messenger()
        )
        let instance = PhotoLibraryPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveImage":
            guard
                let args = call.arguments as? [String: Any],
                let path = args["path"] as? String
            else {
                result(
                    FlutterError(
                        code: "invalid_args",
                        message: "保存パスが必要です",
                        details: nil
                    )
                )
                return
            }
            saveImage(path: path, result: result)

        case "saveImages":
            guard
                let args = call.arguments as? [String: Any],
                let paths = args["paths"] as? [String]
            else {
                result(
                    FlutterError(
                        code: "invalid_args",
                        message: "保存パス一覧が必要です",
                        details: nil
                    )
                )
                return
            }
            saveImages(paths: paths, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func saveImage(path: String, result: @escaping FlutterResult) {
        requestAccess { error in
            if let error {
                result(error)
                return
            }
            self.performSave(urls: [URL(fileURLWithPath: path)], result: result)
        }
    }

    private func saveImages(paths: [String], result: @escaping FlutterResult) {
        requestAccess { error in
            if let error {
                result(error)
                return
            }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            self.performSave(urls: urls, result: result)
        }
    }

    private func requestAccess(
        completion: @escaping (FlutterError?) -> Void
    ) {
        let handler: (PHAuthorizationStatus) -> Void = { status in
            DispatchQueue.main.async {
                let isLimited: Bool
                if #available(iOS 14, *) {
                    isLimited = status == .limited
                } else {
                    isLimited = false
                }

                switch status {
                case .authorized:
                    completion(nil)
                case .denied, .restricted:
                    completion(
                        FlutterError(
                            code: "permission_denied",
                            message: "写真アプリへの保存が許可されていません",
                            details: nil
                        )
                    )
                case .notDetermined:
                    completion(
                        FlutterError(
                            code: "permission_pending",
                            message: "写真アプリへの保存権限を確認できませんでした",
                            details: nil
                        )
                    )
                default:
                    if isLimited {
                        completion(nil)
                        return
                    }
                    completion(
                        FlutterError(
                            code: "permission_unknown",
                            message: "写真アプリの権限状態を確認できませんでした",
                            details: nil
                        )
                    )
                }
            }
        }

        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: handler)
        } else {
            PHPhotoLibrary.requestAuthorization(handler)
        }
    }

    private func performSave(urls: [URL], result: @escaping FlutterResult) {
        let existingURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existingURLs.isEmpty else {
            result(
                FlutterError(
                    code: "file_not_found",
                    message: "保存できる画像がありません",
                    details: nil
                )
            )
            return
        }

        PHPhotoLibrary.shared().performChanges({
            for url in existingURLs {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if let error {
                    result(
                        FlutterError(
                            code: "save_failed",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                    return
                }

                if success {
                    result(existingURLs.count)
                } else {
                    result(
                        FlutterError(
                            code: "save_failed",
                            message: "写真アプリへの保存に失敗しました",
                            details: nil
                        )
                    )
                }
            }
        })
    }
}
