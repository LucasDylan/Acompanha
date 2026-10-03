import Flutter
import UIKit
import GoogleMaps
import FBSDKCoreKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps: replace with your Maps SDK for iOS API key.
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    ApplicationDelegate.shared.application(app, open: url, options: options)
  }
}
