import UIKit
import Flutter
import GoogleMaps // <-- ADD IMPORT

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ADD Your API Key Here
    GMSServices.provideAPIKey("AIzaSyCb5HmOC7NMgHy537YCFprdFDHZi5HsVVQ") // <-- REPLACE VALUE

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}