import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  // Shared across all windows/engines in the process
  private static var activityToken: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // ── Register App Nap control for MAIN engine ─────────────────────────
    let mainAppNapChannel = FlutterMethodChannel(
      name: "lycri/app_nap",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    Self.setupAppNapHandler(on: mainAppNapChannel)

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

    // ── System events (e.g. screen changes) ────────────────────────────────
    let eventChannel = FlutterMethodChannel(
      name: "lycri/system_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
      eventChannel.invokeMethod("onScreensChanged", arguments: nil)
    }

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)

      // ── Register App Nap control for SUB-WINDOW engine ───────────────────
      let subAppNapChannel = FlutterMethodChannel(
        name: "lycri/app_nap",
        binaryMessenger: controller.engine.binaryMessenger
      )
      Self.setupAppNapHandler(on: subAppNapChannel)

      // ── Native window-setup channel for sub-windows ───────────────────
      let setupChannel = FlutterMethodChannel(
        name: "lycri/window_setup",
        binaryMessenger: controller.engine.binaryMessenger
      )
      setupChannel.setMethodCallHandler { [weak controller] (call, result) in
        guard let win = controller?.view.window else {
          result(FlutterError(code: "NO_WINDOW", message: "NSWindow not available", details: nil))
          return
        }

        switch call.method {
        case "setFrame":
          guard let args = call.arguments as? [String: Any],
                let x = args["x"] as? Double,
                let y = args["y"] as? Double,
                let w = args["width"] as? Double,
                let h = args["height"] as? Double
          else {
            result(FlutterError(code: "BAD_ARGS", message: "Expected x/y/width/height", details: nil))
            return
          }
          let screenHeight = NSScreen.screens.first?.frame.height ?? 0
          let flippedY = screenHeight - y - h
          DispatchQueue.main.async {
            win.setFrame(NSRect(x: x, y: flippedY, width: w, height: h), display: true)
            result(nil)
          }

        case "setFullScreen":
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

        case "close":
          DispatchQueue.main.async {
            win.close()
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }

  /// Shared handler setup for both main and sub-window engines.
  private static func setupAppNapHandler(on channel: FlutterMethodChannel) {
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "disableAppNap":
        if activityToken == nil {
          print("Lycri Native: Disabling App Nap (Global Performance Mode ON)")
          activityToken = ProcessInfo.processInfo.beginActivity(
            options: [
              .userInitiated,
              .idleSystemSleepDisabled,
              .latencyCritical,
              .background,
              .suddenTerminationDisabled,
              .automaticTerminationDisabled
            ],
            reason: "Active Presentation / NDI Stream"
          )
        }
        result(nil)
      case "enableAppNap":
        if let token = activityToken {
          print("Lycri Native: Enabling App Nap (Global Performance Mode OFF)")
          ProcessInfo.processInfo.endActivity(token)
          activityToken = nil
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
