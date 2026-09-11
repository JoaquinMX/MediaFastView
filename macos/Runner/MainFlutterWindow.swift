import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Hosted native tests instantiate their own handlers. Starting Flutter here
    // would run main.dart and open/migrate the user's real application database.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || NSClassFromString("XCTestCase") != nil {
      super.awakeFromNib()
      return
    }
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let accessRegistry = SecurityScopedAccessRegistry()

    // Set up bookmark method channel
    let bookmarkChannel = FlutterMethodChannel(name: "com.joaquinmx.media_fast_view/bookmarks",
                                               binaryMessenger: flutterViewController.engine.binaryMessenger)
    let bookmarkHandler = BookmarkHandler(accessRegistry: accessRegistry)
    bookmarkChannel.setMethodCallHandler(bookmarkHandler.handle)

    let thumbnailChannel = FlutterMethodChannel(name: "com.joaquinmx.media_fast_view/thumbnails",
                                                binaryMessenger: flutterViewController.engine.binaryMessenger)
    let thumbnailHandler = ThumbnailHandler(accessRegistry: accessRegistry)
    thumbnailHandler.setVisionSessionProgressEmitter { payload in
      DispatchQueue.main.async {
        thumbnailChannel.invokeMethod("visionSessionUpdate", arguments: payload)
      }
    }
    thumbnailChannel.setMethodCallHandler(thumbnailHandler.handle)

    super.awakeFromNib()
  }
}
