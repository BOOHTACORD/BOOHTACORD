// Synthetic frames through the WebRTC adapter using a test interface stub.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/webrtc_capture_adapter.h"
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/capture_hook/runtime_hook.h"
#include "research_engine.h"
#define NOMINMAX
#include <windows.h>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <thread>

using namespace boohta;
using namespace boohta::deepfilter;
using Clock = std::chrono::steady_clock;

int main(int argc, char** argv) {
  if (argc != 3) return 2;
  HMODULE dll = LoadLibraryExA(argv[1], nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (!dll) return 3;
  auto create = reinterpret_cast<Create>(GetProcAddress(dll, "research_create"));
  auto process = reinterpret_cast<Process>(GetProcAddress(dll, "research_process"));
  auto free_state = reinterpret_cast<Free>(GetProcAddress(dll, "research_free"));
  if (!create || !process || !free_state) { FreeLibrary(dll); return 4; }
  ResearchEngine engine{create, process, free_state, argv[2]};
  WorkerRuntime<ResearchEngine, 8> runtime(engine, 4);
  RuntimeHook<ResearchEngine, 8> hook(runtime);
  WebrtcCaptureAdapter adapter(&hook);
  auto& capture = adapter.processor;
  adapter.Initialize(48000, 1);
  if (!runtime.Launch()) { FreeLibrary(dll); return 5; }
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
  float pcm[480]{};
  adapter.Process(1, 480, 480, pcm);
  bool ok = capture.fallback_frames() == 0;
  const auto deadline = Clock::now() + std::chrono::seconds(20);
  while (runtime.Snapshot().state == LifecycleState::starting && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  auto next = Clock::now();
  unsigned submitted = 0;
  for (int frame = 0; frame < 300 && ok && runtime.Snapshot().state == LifecycleState::active; ++frame) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((frame * 480 + i) * 0.05f);
    adapter.Process(1, 480, 480, pcm);
    ok = capture.fallback_frames() == 0;
    ++submitted;
    next += std::chrono::milliseconds(10); std::this_thread::sleep_until(next);
  }
  const auto effective = capture.EffectiveEngine();
  const auto processed = capture.processed_frames(), fallback = capture.fallback_frames();
  const auto state = runtime.Snapshot().state;
  capture.SetEngine(RnnoiseCaptureProcessor::Engine::kBrowser);
  const bool closed = runtime.Shutdown();
  ok = ok && submitted == 300 && processed > 0 && fallback == 0 && closed &&
       state == LifecycleState::active && effective == RnnoiseCaptureProcessor::Engine::kDeepFilter;
  std::printf("capture_hook=%s submitted=%u processed=%llu fallbacks=%llu\n", ok ? "SMOKE_COMPLETED" : "FAIL",
              submitted, static_cast<unsigned long long>(processed), static_cast<unsigned long long>(fallback));
  FreeLibrary(dll);
  return ok ? 0 : 1;
}
