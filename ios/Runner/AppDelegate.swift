import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let registrar = self.registrar(forPlugin: "CameraPlugin")!
        CameraPlugin.register(with: registrar)
        let photoLibraryRegistrar = self.registrar(forPlugin: "PhotoLibraryPlugin")!
        PhotoLibraryPlugin.register(with: photoLibraryRegistrar)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
