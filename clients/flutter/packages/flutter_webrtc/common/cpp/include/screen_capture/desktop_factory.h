#ifndef BOOHTACORD_SCREEN_CAPTURE_DESKTOP_FACTORY_H_
#define BOOHTACORD_SCREEN_CAPTURE_DESKTOP_FACTORY_H_

#include "rtc_desktop_device.h"

namespace flutter_webrtc_plugin {

// Use the SDK's compositor-backed window path where Windows supports it.
// The SDK retains its OS-capability fallback and the visible capture border.
template <typename Device, typename Source>
auto CreateProfiledDesktopCapturer(Device* device, Source source, bool cursor) {
#ifdef _WIN32
  libwebrtc::RTCDesktopCapturerOptions options;
  options.show_cursor = cursor;
  options.allow_wgc_window_capturer = true;
  options.focus_window = false;
  return device->CreateDesktopCapturerWithOptions(source, options);
#else
  return device->CreateDesktopCapturer(source, cursor);
#endif
}

}  // namespace flutter_webrtc_plugin
#endif
