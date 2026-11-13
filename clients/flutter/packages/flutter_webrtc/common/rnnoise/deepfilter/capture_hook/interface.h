#ifndef BOOHTA_DEEPFILTER_CAPTURE_HOOK_H_
#define BOOHTA_DEEPFILTER_CAPTURE_HOOK_H_
#include "../capture_guard/guard.h"

namespace boohta::deepfilter {
enum class HookReadiness { preparing, ready, failed };
// Borrowed for the life of the capture processor. The owner must stop capture
// before destruction and must never perform model loading on the callback.
class CaptureHook {
 public:
  virtual ~CaptureHook() = default;
  virtual void Reset(bool enabled) noexcept = 0;
  virtual bool Available() const noexcept = 0;
  virtual HookReadiness Readiness() const noexcept = 0;
  virtual GuardStatus Capture(float* pcm, int frames, int capacity, int rate, int channels) noexcept = 0;
};
}  // namespace boohta::deepfilter
#endif
