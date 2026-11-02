import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var windowChannel: FlutterMethodChannel?
  private var normalFrame: NSRect?
  private var normalMinSize = NSSize.zero
  private var normalLevel = NSWindow.Level.normal
  private var closeBehavior = "exit"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    delegate = self
    let channel = FlutterMethodChannel(
      name: "ting_reader/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "setMiniMode":
        self.setMiniMode(call.arguments as? Bool ?? false)
      case "setCloseBehavior":
        self.closeBehavior = call.arguments as? String ?? "ask"
      case "minimize": self.miniaturize(nil)
      case "close": self.performClose(nil)
      case "exit": NSApp.terminate(nil)
      case "toggleMaximize":
        let force = call.arguments as? Bool ?? false
        let wasMini = self.normalFrame != nil
        if wasMini { self.setMiniMode(false) }
        if !(force || wasMini) || !self.isZoomed { self.zoom(nil) }
        result(self.isZoomed)
        return
      case "startDragging":
        if let event = NSApp.currentEvent { self.performDrag(with: event) }
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }

    super.awakeFromNib()
  }

  private func setMiniMode(_ enabled: Bool) {
    if enabled {
      guard normalFrame == nil else { return }
      normalFrame = frame
      normalMinSize = minSize
      normalLevel = level
      minSize = NSSize(width: 420, height: 174)
      setContentSize(NSSize(width: 560, height: 174))
      level = .floating
    } else if let previous = normalFrame {
      normalFrame = nil
      minSize = normalMinSize
      level = normalLevel
      setFrame(previous, display: true)
    }
    windowChannel?.invokeMethod("miniModeChanged", arguments: enabled)
  }

  func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
    if normalFrame != nil { setMiniMode(false) }
    return true
  }

  func windowWillEnterFullScreen(_ notification: Notification) {
    if normalFrame != nil { setMiniMode(false) }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if closeBehavior == "exit" { NSApp.terminate(nil) }
    else if closeBehavior == "minimize" { miniaturize(nil) }
    else { windowChannel?.invokeMethod("closeRequested", arguments: nil) }
    return false
  }
}
