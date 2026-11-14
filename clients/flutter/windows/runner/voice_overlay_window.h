#ifndef RUNNER_VOICE_OVERLAY_WINDOW_H_
#define RUNNER_VOICE_OVERLAY_WINDOW_H_

#include <windows.h>

#include <string>
#include <vector>
#include <functional>
#include "voice_overlay/configuration/model.h"

struct VoiceOverlayMember {
  std::wstring display_name;
  bool speaking;
  bool microphone_muted;
  bool deafened;
};

class VoiceOverlayWindow {
 public:
  VoiceOverlayWindow() = default;
  ~VoiceOverlayWindow();

  bool Create(HWND anchor_window);
  void SetSnapshot(bool visible,
                   const std::vector<VoiceOverlayMember>& members);
  void Destroy();
  bool Configure(const VoiceOverlayConfiguration& configuration);
  std::function<void(const VoiceOverlayConfiguration&)> placement_changed;
  std::function<void(int)> shortcut_error;

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void Position();
  void Paint();
  bool RegisterShortcut();
  void UpdateVisibility();
  void EndDrag();
  int Layout(int dip) const;

  HWND window_ = nullptr;
  HWND anchor_window_ = nullptr;
  std::vector<VoiceOverlayMember> members_;
  bool visible_ = false;
  bool hotkey_hidden_ = false, shortcut_registered_ = false, dragging_ = false;
  bool shortcut_failed_ = false;
  POINT drag_origin_{}, window_origin_{};
  VoiceOverlayConfiguration configuration_;
};

#endif  // RUNNER_VOICE_OVERLAY_WINDOW_H_
