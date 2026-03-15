import UIKit
import Flutter
import geolocator_apple
#if canImport(mapbox_maps_flutter)
import mapbox_maps_flutter
#endif
import share_plus
import shared_preferences_foundation
import sqflite_darwin

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

        GeolocatorPlugin.register(with: self.registrar(forPlugin: "GeolocatorPlugin")!)
        FPPSharePlusPlugin.register(with: self.registrar(forPlugin: "FPPSharePlusPlugin")!)
        SharedPreferencesPlugin.register(with: self.registrar(forPlugin: "SharedPreferencesPlugin")!)
        SqflitePlugin.register(with: self.registrar(forPlugin: "SqflitePlugin")!)

        #if canImport(mapbox_maps_flutter)
        if shouldRegisterMapboxPlugin() {
            MapboxMapsPlugin.register(with: self.registrar(forPlugin: "MapboxMapsPlugin")!)
        }
        #endif

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func shouldRegisterMapboxPlugin() -> Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        if let forceDisable = info["SMAPDisableMapboxPlugin"] as? Bool, forceDisable {
            return false
        }
        if let forceEnable = info["SMAPForceEnableMapboxPlugin"] as? Bool, forceEnable {
            return true
        }
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
    }
}
