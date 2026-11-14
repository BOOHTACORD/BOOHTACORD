// Synthetic research probe: production owner + adapter, stub WebRTC interface.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/webrtc_capture_adapter.h"
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/owner/owner.h"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <thread>
#include <cstring>
using namespace boohta;
using namespace boohta::deepfilter;
using Clock = std::chrono::steady_clock;
int wmain(int argc, wchar_t** argv) {
  if (argc != 4) return 2;
  const std::wstring hash_text(argv[2]);
  if (hash_text.size() != 64) return 2;
  std::string hash;
  for (wchar_t c : hash_text) { if (c > 127) return 2; hash.push_back(static_cast<char>(c)); }
  ExperimentalOwner owner;
  if (!owner.Open(argv[1], hash.c_str(), argv[3],
      "c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616")) return 3;
  WebrtcCaptureAdapter adapter(owner.hook());
  const auto identity = adapter.processor.DeepFilterModelId();
  if (!identity || std::strcmp(identity, "deepfilternet3-research-d375b2d") != 0) return 5;
  adapter.Initialize(48000, 1);
  auto& capture = adapter.processor;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
  const auto started = Clock::now(), deadline = started + std::chrono::seconds(20);
  while (owner.hook()->Readiness() == HookReadiness::preparing && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  const auto prepare_ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - started).count();
  if (owner.hook()->Readiness() != HookReadiness::ready) return 4;
  float pcm[480]{};
  unsigned submitted = 0;
  bool ok = true;
  auto next = Clock::now();
  for (int frame = 0; frame < 300 && ok; ++frame) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((frame * 480 + i) * 0.05f);
    adapter.Process(1, 480, 480, pcm);
    ok = capture.fallback_frames() == 0;
    ++submitted;
    next += std::chrono::milliseconds(10);
    std::this_thread::sleep_until(next);
  }
  const auto processed = capture.processed_frames(), fallback = capture.fallback_frames();
  ok = ok && submitted == 300 && processed > 0 && fallback == 0 &&
      capture.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kDeepFilter;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kBrowser);
  std::printf("owner_probe=%s prepare_ms=%lld submitted=%u processed=%llu fallbacks=%llu\n",
      ok ? "SMOKE_COMPLETED" : "FAIL", static_cast<long long>(prepare_ms), submitted,
      static_cast<unsigned long long>(processed), static_cast<unsigned long long>(fallback));
  return ok ? 0 : 1;
}
