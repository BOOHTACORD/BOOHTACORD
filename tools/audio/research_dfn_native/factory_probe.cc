// Local opt-in probe for the same automatic owner path compiled into the plugin.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/webrtc_capture_adapter.h"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <thread>
using namespace boohta;
using Clock = std::chrono::steady_clock;
int main(int argc, char** argv) {
  if (argc != 2) return 2;
  const bool expect_model = std::strcmp(argv[1], "model") == 0;
  WebrtcCaptureAdapter adapter;
  adapter.Initialize(48000, 1);
  auto& capture = adapter.processor;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
  if (!expect_model) {
    const bool ok = !capture.supported() && std::strcmp(capture.failure_reason(), "processor-unavailable") == 0;
    std::printf("factory_without_model=%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 3;
  }
  const auto start = Clock::now(), deadline = start + std::chrono::seconds(20);
  while (std::strcmp(capture.failure_reason(), "awaiting-model") == 0 && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  if (std::strcmp(capture.failure_reason(), "awaiting-audio") != 0) return 4;
  const auto prepare_ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - start).count();
  float pcm[480]{};
  auto next = Clock::now();
  unsigned submitted = 0;
  while (submitted < 300 && capture.fallback_frames() == 0) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((submitted * 480 + i) * 0.05f);
    adapter.Process(1, 480, 480, pcm);
    ++submitted;
    next += std::chrono::milliseconds(10);
    std::this_thread::sleep_until(next);
  }
  const auto processed = capture.processed_frames(), fallback = capture.fallback_frames();
  const bool ok = submitted == 300 && processed > 0 && fallback == 0 &&
      capture.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kDeepFilter;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kBrowser);
  std::printf("factory_probe=%s prepare_ms=%lld submitted=%u processed=%llu fallbacks=%llu\n",
      ok ? "SMOKE_COMPLETED" : "FAIL", static_cast<long long>(prepare_ms), submitted,
      static_cast<unsigned long long>(processed), static_cast<unsigned long long>(fallback));
  return ok ? 0 : 1;
}
