#include "../../webrtc_capture_adapter.h"
#include "interface.h"
#include <cassert>

struct FakeHook : boohta::deepfilter::CaptureHook {
  bool enabled = false;
  void Reset(bool value) noexcept override { enabled = value; }
  bool Available() const noexcept override { return true; }
  boohta::deepfilter::HookReadiness Readiness() const noexcept override { return boohta::deepfilter::HookReadiness::ready; }
  boohta::deepfilter::GuardStatus Capture(float* pcm, int frames, int, int, int) noexcept override {
    for (int i = 0; i < frames; ++i) pcm[i] *= 0.5f;
    return boohta::deepfilter::GuardStatus::ready;
  }
};
int main() {
  FakeHook hook;
  boohta::WebrtcCaptureAdapter adapter(&hook);
  adapter.Initialize(48000, 1);
  adapter.processor.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kDeepFilter);
  assert(hook.enabled);
  float pcm[480]; for (float& x : pcm) x = 2000.f;
  adapter.Process(1, 480, 480, pcm);
  for (float x : pcm) assert(x == 1000.f);
  adapter.processor.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kBrowser);
  assert(!hook.enabled);
  adapter.Release();
}
