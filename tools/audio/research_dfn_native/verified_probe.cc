// Synthetic adapter/worker test with verified, locked research artifacts.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/webrtc_capture_adapter.h"
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/capture_hook/runtime_hook.h"
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/verified_engine/engine.h"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <thread>

using namespace boohta;
using namespace boohta::deepfilter;
using Clock = std::chrono::steady_clock;
int wmain(int argc, wchar_t** argv) {
  if (argc != 4) return 2;
  const std::wstring hash_text(argv[2]);
  if (hash_text.size() != 64) return 2;
  std::string hash;
  for (wchar_t c : hash_text) {
    if (c > 127) return 2;
    hash.push_back(static_cast<char>(c));
  }
  VerifiedEngine engine;
  if (!engine.Open(argv[1], hash.c_str(), argv[3],
                   "c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616")) return 3;
  WorkerRuntime<VerifiedEngine, 8> runtime(engine, 4);
  RuntimeHook<VerifiedEngine, 8> hook(runtime);
  WebrtcCaptureAdapter adapter(&hook);
  auto& capture = adapter.processor;
  adapter.Initialize(48000, 1);
  if (!runtime.Launch()) return 4;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
  float pcm[480]{};
  adapter.Process(1, 480, 480, pcm);
  bool ok = capture.fallback_frames() == 0;
  const auto deadline = Clock::now() + std::chrono::seconds(20);
  while (runtime.Snapshot().state == LifecycleState::starting && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  unsigned submitted = 0;
  auto next = Clock::now();
  for (int frame = 0; frame < 300 && ok && runtime.Snapshot().state == LifecycleState::active; ++frame) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((frame * 480 + i) * 0.05f);
    adapter.Process(1, 480, 480, pcm);
    ok = capture.fallback_frames() == 0;
    ++submitted;
    next += std::chrono::milliseconds(10); std::this_thread::sleep_until(next);
  }
  const auto effective = capture.EffectiveEngine();
  const auto processed = capture.processed_frames(), fallback = capture.fallback_frames();
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kBrowser);
  const bool closed = runtime.Shutdown();
  ok = ok && submitted == 300 && processed > 0 && fallback == 0 && closed &&
       effective == RnnoiseCaptureProcessor::Engine::kDeepFilter;
  std::printf("verified_hook=%s submitted=%u processed=%llu fallbacks=%llu\n", ok ? "SMOKE_COMPLETED" : "FAIL",
              submitted, static_cast<unsigned long long>(processed), static_cast<unsigned long long>(fallback));
  return ok ? 0 : 1;
}
