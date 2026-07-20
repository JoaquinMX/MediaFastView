import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
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
    thumbnailChannel.setMethodCallHandler(thumbnailHandler.handle)

    super.awakeFromNib()
  }
}
