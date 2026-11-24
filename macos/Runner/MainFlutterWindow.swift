import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Sadržaj ide i ispod providne naslovne trake: semafori stoje u vrhu
    // bočne navigacije, a naziv prozora se ne prikazuje (platno, macOS).
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = false

    let channel = FlutterMethodChannel(
      name: "tavli/macos_window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "isFullScreen" {
        result(self?.styleMask.contains(.fullScreen) ?? false)
      } else if call.method == "activate" {
        // Link iz mejla („Otvori Tavli“): prozor ispred pregledača.
        NSApp.activate(ignoringOtherApps: true)
        self?.makeKeyAndOrderFront(nil)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel
    for notification in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(fullScreenChanged), name: notification, object: self)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown, !styleMask.contains(.fullScreen),
      let zoomButton = standardWindowButton(.zoomButton)
    {
      // Prazan deo iznad bočne navigacije, u istom redu kao semafori.
      let buttonFrame = zoomButton.convert(zoomButton.bounds, to: nil)
      let point = event.locationInWindow
      if point.x >= buttonFrame.maxX + 8, point.x < 200,
        point.y >= buttonFrame.minY - 6, point.y <= buttonFrame.maxY + 4
      {
        performDrag(with: event)
        return
      }
    }
    super.sendEvent(event)
  }

  @objc private func fullScreenChanged(_ notification: Notification) {
    windowChannel?.invokeMethod(
      "fullScreenChanged", arguments: notification.name == NSWindow.didEnterFullScreenNotification)
  }
}
