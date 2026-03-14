import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // ── System fonts method channel ───────────────────────────────────────
    let fontChannel = FlutterMethodChannel(
      name: "com.lycri/system_fonts",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fontChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getSystemFonts":
        let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
        result(fontFamilies)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      // Register plugins for each sub-window so method channels work.
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
