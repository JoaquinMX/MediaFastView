import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let bookmarkHandler = BookmarkHandler()
  private let thumbnailHandler = ThumbnailHandler()

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
      bookmarkChannel.setMethodCallHandler(bookmarkHandler.handle)

      let thumbnailChannel = FlutterMethodChannel(
        name: "com.joaquinmx.media_fast_view/thumbnails",
        binaryMessenger: controller.binaryMessenger
      )
      thumbnailChannel.setMethodCallHandler(thumbnailHandler.handle)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
