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

        case "setCleanFeed":
          // Frameless, shadowless window for vMix / OBS window capture.
          guard let args = call.arguments as? [String: Any],
                let enabled = args["enabled"] as? Bool
          else {
            result(FlutterError(code: "BAD_ARGS", message: "Expected enabled bool", details: nil))
            return
          }
          let title = args["title"] as? String
          let pixelSize = (args["pixelWidth"] as? Double).flatMap { w in
            (args["pixelHeight"] as? Double).map { h in NSSize(width: w, height: h) }
          }
          let screenPoint = (args["screenX"] as? Double).flatMap { x in
            (args["screenY"] as? Double).map { y in NSPoint(x: x, y: y) }
          }
          DispatchQueue.main.async {
            Self.setCleanFeed(
              enabled, title: title, pixelSize: pixelSize,
              screen: Self.screen(atTopLeft: screenPoint), on: win
            ) {
              result(nil)
            }
          }

        case "startDrag":
          DispatchQueue.main.async {
            if let event = NSApp.currentEvent {
              win.performDrag(with: event)
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

  private static let framedStyle: NSWindow.StyleMask =
    [.titled, .closable, .miniaturizable, .resizable]

  /// Switches a sub-window between the frameless clean feed and a normal
  /// titled window. Leaves fullscreen first: the style mask can't change
  /// mid-transition.
  ///
  /// [pixelSize] is the capture resolution; the window is sized to it in
  /// points for [screen]'s backing scale (default: primary) and centered there.
  private static func setCleanFeed(
    _ enabled: Bool, title: String?, pixelSize: NSSize?, screen: NSScreen? = nil,
    on win: NSWindow, completion: @escaping () -> Void
  ) {
    if enabled && win.styleMask.contains(.fullScreen) {
      let observer = ObserverBox()
      observer.token = NotificationCenter.default.addObserver(
        forName: NSWindow.didExitFullScreenNotification, object: win, queue: .main
      ) { _ in
        if let token = observer.token { NotificationCenter.default.removeObserver(token) }
        setCleanFeed(
          enabled, title: title, pixelSize: pixelSize, screen: screen, on: win,
          completion: completion)
      }
      win.toggleFullScreen(nil)
      return
    }

    if enabled {
      win.styleMask = [.borderless]
      win.hasShadow = false
      if let pixelSize = pixelSize, let screen = screen ?? NSScreen.screens.first {
        let scale = screen.backingScaleFactor
        let size = NSSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        let area = screen.visibleFrame
        // Keep the top edge on-screen if the feed is taller than the screen.
        let origin = NSPoint(
          x: area.minX + max(0, (area.width - size.width) / 2),
          y: area.maxY - size.height - max(0, (area.height - size.height) / 2))
        win.setFrame(NSRect(origin: origin, size: size), display: true)
      }
    } else if !win.styleMask.contains(.titled) {
      win.styleMask = framedStyle
      win.hasShadow = true
    }
    if let title = title { win.title = title }
    completion()
  }

  /// The screen containing [point], given with a top-left origin (as
  /// screen_retriever reports displays).
  private static func screen(atTopLeft point: NSPoint?) -> NSScreen? {
    guard let point = point, let primary = NSScreen.screens.first else { return nil }
    let flipped = NSPoint(x: point.x, y: primary.frame.height - point.y)
    return NSScreen.screens.first { $0.frame.contains(flipped) }
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

/// Holds a one-shot notification observer so its own block can remove it.
private final class ObserverBox: @unchecked Sendable {
  var token: NSObjectProtocol?
}
