import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Enforce a sensible minimum size for desktop
    self.minSize = NSSize(width: 820, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Hides the window before window_manager shows it with the correct
  // title bar style, preventing a flash of the native chrome.
  override public func order(
    _ place: NSWindow.OrderingMode, relativeTo otherWin: Int
  ) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
