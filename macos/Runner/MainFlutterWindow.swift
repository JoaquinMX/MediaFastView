import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Set up bookmark method channel
    let bookmarkChannel = FlutterMethodChannel(name: "com.joaquinmx.media_fast_view/bookmarks",
                                               binaryMessenger: flutterViewController.engine.binaryMessenger)
    let bookmarkHandler = BookmarkHandler()
    bookmarkChannel.setMethodCallHandler(bookmarkHandler.handle)

    super.awakeFromNib()
  }
}
