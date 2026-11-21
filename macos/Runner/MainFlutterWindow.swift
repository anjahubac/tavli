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

  @objc private func fullScreenChanged(_ notification: Notification) {
    windowChannel?.invokeMethod(
      "fullScreenChanged", arguments: notification.name == NSWindow.didEnterFullScreenNotification)
  }
}
