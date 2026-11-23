#include <cassert>
#include "screen_capture/desktop_factory.h"

struct Device {
  int modern_calls = 0;
  int legacy_calls = 0;
  int selected = 0;
  libwebrtc::RTCDesktopCapturerOptions seen;
  int CreateDesktopCapturerWithOptions(
      int source, const libwebrtc::RTCDesktopCapturerOptions& options) {
    modern_calls++;
    selected = source;
    seen = options;
    return 37;
  }
  int CreateDesktopCapturer(int, bool) { legacy_calls++; return -1; }
};

int main() {
  Device device;
  assert(flutter_webrtc_plugin::CreateProfiledDesktopCapturer(
             &device, 19, false) == 37);
  assert(device.modern_calls == 1 && device.legacy_calls == 0);
  assert(device.selected == 19);
  assert(device.seen.allow_wgc_window_capturer);
  assert(device.seen.wgc_border_required);
  assert(!device.seen.focus_window);
  assert(!device.seen.show_cursor);
  flutter_webrtc_plugin::CreateProfiledDesktopCapturer(&device, 23, true);
  assert(device.selected == 23 && device.seen.show_cursor);
}
