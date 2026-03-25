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
      // Register all plugins (window_manager, etc.) for each sub-window engine.
      RegisterGeneratedPlugins(registry: controller)

      // ── Native window-setup channel for sub-windows ───────────────────
      // We cannot use `windowManager` (window_manager package) inside a
      // sub-window because its Swift plugin force-unwraps NSApp.mainWindow,
      // which is nil in sub-window contexts. Instead we register a lightweight
      // native channel here, giving the sub-window direct access to its own
      // NSWindow so it can set its frame and toggle fullscreen safely.
      let setupChannel = FlutterMethodChannel(
        name: "lycri/window_setup",
        binaryMessenger: controller.engine.binaryMessenger
      )

      // Capture the sub-window's NSWindow weakly so this closure doesn't
      // outlive the window.
      setupChannel.setMethodCallHandler { [weak controller] (call, result) in
        guard let win = controller?.view.window else {
          result(FlutterError(code: "NO_WINDOW", message: "NSWindow not available", details: nil))
          return
        }

        switch call.method {

        case "setFrame":
          // args: { x, y, width, height }  — all in top-left screen coordinates.
          guard let args = call.arguments as? [String: Any],
                let x = args["x"] as? Double,
                let y = args["y"] as? Double,
                let w = args["width"] as? Double,
                let h = args["height"] as? Double
          else {
            result(FlutterError(code: "BAD_ARGS", message: "Expected x/y/width/height", details: nil))
            return
          }

          // macOS screen coordinates are bottom-left origin. Convert from
          // top-left (Flutter / screen_retriever convention) to bottom-left.
          let screenHeight = NSScreen.screens.first?.frame.height ?? 0
          let flippedY = screenHeight - y - h

          DispatchQueue.main.async {
            win.setFrame(NSRect(x: x, y: flippedY, width: w, height: h), display: true)
            result(nil)
          }

        case "setFullScreen":
          // args: { fullScreen: bool }
          guard let args = call.arguments as? [String: Any],
                let fs = args["fullScreen"] as? Bool
          else {
            result(FlutterError(code: "BAD_ARGS", message: "Expected fullScreen bool", details: nil))
            return
          }

          DispatchQueue.main.async {
            let isAlready = win.styleMask.contains(.fullScreen)
            if fs && !isAlready {
              win.toggleFullScreen(nil)
            } else if !fs && isAlready {
              win.toggleFullScreen(nil)
            }
            result(nil)
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }
}
