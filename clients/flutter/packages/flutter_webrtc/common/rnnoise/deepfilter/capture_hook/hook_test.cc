#include "../../rnnoise_capture_processor.h"
#include "interface.h"
#include "runtime_hook.h"
#include <cassert>
#include <string>

using namespace boohta;
using namespace boohta::deepfilter;
struct FakeHook : CaptureHook {
  bool enabled = false, available = true;
  GuardStatus status = GuardStatus::ready;
  HookReadiness readiness = HookReadiness::ready;
  void Reset(bool value) noexcept override { enabled = value; }
  bool Available() const noexcept override { return available; }
  HookReadiness Readiness() const noexcept override { return readiness; }
  GuardStatus Capture(float* pcm, int frames, int, int, int) noexcept override {
    if (status == GuardStatus::ready) for (int i = 0; i < frames; ++i) pcm[i] *= 0.5f;
    return status;
  }
};
struct FakeEngine {
  bool Reset() { return true; }
  bool Process(AudioFrame& frame) { for (float& x : frame.samples) x *= 0.5f; return true; }
  bool Close() { return true; }
};
int main() {
  using Engine = RnnoiseCaptureProcessor::Engine;
  RnnoiseCaptureProcessor absent;
  absent.SetEngine(Engine::kDeepFilter);
  absent.Initialize(48000, 1);
  float pcm[480]; for (float& x : pcm) x = 2000.f;
  assert(!absent.supported());
  assert(!absent.Process(pcm, 480, 480));
  assert(absent.EffectiveEngine() == Engine::kUnknown);
  assert(std::string(absent.failure_reason()) == "processor-unavailable");

  FakeHook hook;
  RnnoiseCaptureProcessor processor(std::malloc, &hook);
  processor.Initialize(48000, 1);
  processor.SetEngine(Engine::kDeepFilter);
  assert(hook.enabled && processor.supported());
  assert(processor.EffectiveEngine() == Engine::kUnknown);
  hook.readiness = HookReadiness::preparing;
  assert(std::string(processor.failure_reason()) == "awaiting-model");
  hook.readiness = HookReadiness::failed;
  assert(std::string(processor.failure_reason()) == "processor-failed");
  hook.readiness = HookReadiness::ready;
  assert(std::string(processor.failure_reason()) == "awaiting-audio");
  assert(processor.Process(pcm, 480, 480));
  assert(pcm[0] == 1000.f && processor.EffectiveEngine() == Engine::kDeepFilter);
  hook.status = GuardStatus::underrun;
  assert(!processor.Process(pcm, 480, 480) && pcm[0] == 1000.f);
  assert(std::string(processor.failure_reason()) == "processor-underrun");
  hook.status = GuardStatus::buffering;
  assert(processor.Process(pcm, 480, 480));
  for (float x : pcm) assert(x == 0.f);
  hook.status = GuardStatus::ready;
  for (float& x : pcm) x = 2000.f;
  assert(processor.Process(pcm, 480, 480));
  assert(processor.EffectiveEngine() == Engine::kDeepFilter);
  hook.status = GuardStatus::stale;
  assert(processor.Process(pcm, 480, 480));
  for (float x : pcm) assert(x == 0.f);
  for (float& x : pcm) x = 1000.f;
  hook.status = GuardStatus::fallback;
  assert(!processor.Process(pcm, 480, 480));
  assert(processor.EffectiveEngine() == Engine::kUnknown);
  assert(std::string(processor.failure_reason()) == "processor-failed");
  processor.SetEngine(Engine::kBrowser);
  assert(!hook.enabled && processor.EffectiveEngine() == Engine::kBrowser);
  assert(!processor.Process(pcm, 480, 480) && pcm[0] == 1000.f);

  FakeHook vad_hook;
  RnnoiseCaptureProcessor vad_processor(std::malloc, &vad_hook);
  vad_processor.Initialize(48000, 1);
  vad_processor.controls.Configure(-50.f, 100.f, true, false, true);
  vad_processor.SetEngine(Engine::kDeepFilter);
  for (int n = 0; n < 4; ++n) {
    for (float& x : pcm) x = 8000.f;
    assert(vad_processor.Process(pcm, 480, 480));
  }
  vad_hook.status = GuardStatus::stale;
  assert(vad_processor.Process(pcm, 480, 480));
  for (float x : pcm) assert(x == 0.f);
  vad_hook.status = GuardStatus::ready;
  for (int n = 0; n < 3; ++n) {
    for (float& x : pcm) x = 0.f;
    assert(vad_processor.Process(pcm, 480, 480));
    for (float x : pcm) assert(x == 0.f);
  }

  FakeEngine engine;
  WorkerRuntime<FakeEngine, 8> runtime(engine, 1);
  RuntimeHook<FakeEngine, 8> actual(runtime);
  RnnoiseCaptureProcessor connected(std::malloc, &actual);
  connected.Initialize(48000, 1);
  assert(runtime.Launch());
  connected.SetEngine(Engine::kDeepFilter);
  for (float& x : pcm) x = 2000.f;
  assert(connected.Process(pcm, 480, 480));
  for (float x : pcm) assert(x == 0.f);
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (runtime.Snapshot().state != LifecycleState::active && std::chrono::steady_clock::now() < deadline)
    std::this_thread::yield();
  assert(runtime.Snapshot().state == LifecycleState::active);
  for (float& x : pcm) x = 2000.f;
  assert(connected.Process(pcm, 480, 480));
  for (float x : pcm) assert(x == 1000.f);
  assert(connected.EffectiveEngine() == Engine::kDeepFilter);
  connected.SetEngine(Engine::kBrowser);
  assert(runtime.Snapshot().state == LifecycleState::muted);
  assert(runtime.Shutdown());
}
