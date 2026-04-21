#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>
#include <vector>
#include <algorithm>

int CALLBACK EnumFontFamExProc(const LOGFONTW* lpelfe, const TEXTMETRICW* lpntme, DWORD FontType, LPARAM lParam) {
  auto* font_list = reinterpret_cast<std::vector<std::string>*>(lParam);
  int utf8Length = WideCharToMultiByte(CP_UTF8, 0, lpelfe->lfFaceName, -1, nullptr, 0, nullptr, nullptr);
  if (utf8Length > 0) {
    std::string utf8Name(utf8Length - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, lpelfe->lfFaceName, -1, &utf8Name[0], utf8Length, nullptr, nullptr);
    if (!utf8Name.empty() && utf8Name[0] != '@') {
      if (std::find(font_list->begin(), font_list->end(), utf8Name) == font_list->end()) {
        font_list->push_back(utf8Name);
      }
    }
  }
  return 1;
}

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

  flutter::MethodChannel<flutter::EncodableValue> fonts_channel(
      flutter_controller_->engine()->messenger(), "com.lycri/system_fonts",
      &flutter::StandardMethodCodec::GetInstance());

  fonts_channel.SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getSystemFonts") {
          HDC hdc = GetDC(nullptr);
          LOGFONTW lf = {0};
          lf.lfCharSet = DEFAULT_CHARSET;
          std::vector<std::string> unique_fonts;
          EnumFontFamiliesExW(hdc, &lf, (FONTENUMPROCW)EnumFontFamExProc, (LPARAM)&unique_fonts, 0);
          ReleaseDC(nullptr, hdc);

          std::sort(unique_fonts.begin(), unique_fonts.end());

          flutter::EncodableList font_list;
          for (const auto& name : unique_fonts) {
            font_list.push_back(flutter::EncodableValue(name));
          }
          result->Success(flutter::EncodableValue(font_list));
        } else {
          result->NotImplemented();
        }
      });

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
    case WM_DISPLAYCHANGE:
      if (flutter_controller_) {
        flutter::MethodChannel<flutter::EncodableValue> channel(
            flutter_controller_->engine()->messenger(), "lycri/system_events",
            &flutter::StandardMethodCodec::GetInstance());
        channel.InvokeMethod("onScreensChanged", nullptr);
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
