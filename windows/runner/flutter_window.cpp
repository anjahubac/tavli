#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "tavli/windows_window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleWindowCall(call, std::move(result));
      });
  maximized_ = IsZoomed(GetHandle()) != 0;

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SIZE:
      // Minimizing keeps the last state, so restore from the taskbar does
      // not flip the maximize button.
      if ((wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED) &&
          window_channel_) {
        const bool maximized = wparam == SIZE_MAXIMIZED;
        if (maximized != maximized_) {
          maximized_ = maximized;
          window_channel_->InvokeMethod(
              "maximizedChanged",
              std::make_unique<flutter::EncodableValue>(maximized));
        }
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleWindowCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND hwnd = GetHandle();
  const std::string& method = call.method_name();
  if (hwnd == nullptr) {
    result->Error("no_window", "The window is closed.");
    return;
  }
  if (method == "isMaximized") {
    result->Success(flutter::EncodableValue(IsZoomed(hwnd) != 0));
    return;
  }
  // Moving and resizing run a modal loop until the mouse is released, so the
  // call is answered first.
  result->Success();
  if (method == "minimize") {
    ShowWindow(hwnd, SW_MINIMIZE);
  } else if (method == "toggleMaximize") {
    ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
  } else if (method == "close") {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
  } else if (method == "startDrag") {
    ReleaseCapture();
    SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  } else if (method == "startResizeTop") {
    if (!IsZoomed(hwnd)) {
      ReleaseCapture();
      SendMessage(hwnd, WM_NCLBUTTONDOWN, HTTOP, 0);
    }
  } else if (method == "showSystemMenu") {
    ShowSystemMenu();
  }
}

void FlutterWindow::ShowSystemMenu() {
  HWND hwnd = GetHandle();
  HMENU menu = GetSystemMenu(hwnd, FALSE);
  if (menu == nullptr) {
    return;
  }
  const bool zoomed = IsZoomed(hwnd) != 0;
  auto enable = [menu](UINT item, bool on) {
    EnableMenuItem(menu, item,
                   MF_BYCOMMAND | (on ? MF_ENABLED : MF_GRAYED));
  };
  enable(SC_RESTORE, zoomed);
  enable(SC_MOVE, !zoomed);
  enable(SC_SIZE, !zoomed);
  enable(SC_MINIMIZE, true);
  enable(SC_MAXIMIZE, !zoomed);
  enable(SC_CLOSE, true);
  POINT cursor;
  GetCursorPos(&cursor);
  const int command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_TOPALIGN | TPM_LEFTALIGN,
      cursor.x, cursor.y, 0, hwnd, nullptr);
  if (command != 0) {
    PostMessage(hwnd, WM_SYSCOMMAND, command, 0);
  }
}
