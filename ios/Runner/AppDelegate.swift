import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let bookmarkChannel = FlutterMethodChannel(
        name: "com.joaquinmx.media_fast_view/bookmarks",
        binaryMessenger: controller.binaryMessenger
      )

      let bookmarkHandler = BookmarkHandler(viewController: controller)
      bookmarkChannel.setMethodCallHandler(bookmarkHandler.handle)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
