import UIKit
import GoogleMaps

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Khởi tạo Google Maps SDK với API key (đọc từ Info.plist)
        if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String, !key.isEmpty {
            GMSServices.provideAPIKey(key)
        }

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
