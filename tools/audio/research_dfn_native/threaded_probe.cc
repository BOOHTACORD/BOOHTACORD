// Isolated synthetic worker experiment; this is not a production audio callback.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/worker_runtime/runtime.h"
#include "research_engine.h"
#define NOMINMAX
#include <windows.h>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <thread>

using namespace boohta::deepfilter;
using Clock = std::chrono::steady_clock;

int main(int argc, char** argv) {
  if (argc != 4) return 2;
  char* end = nullptr;
  const auto delay = std::strtoul(argv[3], &end, 10);
  if (end == argv[3] || *end || delay > 4) return 2;
  HMODULE dll = LoadLibraryExA(argv[1], nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (!dll) return 3;
  auto create = reinterpret_cast<Create>(GetProcAddress(dll, "research_create"));
  auto process = reinterpret_cast<Process>(GetProcAddress(dll, "research_process"));
  auto free_state = reinterpret_cast<Free>(GetProcAddress(dll, "research_free"));
  if (!create || !process || !free_state) { FreeLibrary(dll); return 4; }
  ResearchEngine engine{create, process, free_state, argv[2]};
  WorkerRuntime<ResearchEngine, 8> runtime(engine, delay);
  if (!runtime.Launch() || !runtime.Start()) { runtime.Shutdown(); FreeLibrary(dll); return 5; }
  bool failed = false;
  float pcm[480]{};
  if (runtime.Capture(pcm, 480, 480, 48000, 1) != (delay ? GuardStatus::buffering : GuardStatus::underrun)) {
    runtime.Shutdown(); FreeLibrary(dll); return 5;
  }
  const auto deadline = Clock::now() + std::chrono::seconds(20);
  while (runtime.Snapshot().state == LifecycleState::starting && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  unsigned ready = 0, buffering = 0, underruns = 0, overloads = 0;
  std::array<unsigned, 32> lag_counts{};
  double peak = 0;
  auto next = Clock::now();
  for (int frame = 0; frame < 300 && runtime.Snapshot().state == LifecycleState::active && !failed; ++frame) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((frame * 480 + i) * 0.05f);
    std::uint64_t emitted;
    const auto status = runtime.Capture(pcm, 480, 480, 48000, 1, &emitted);
    if (status == GuardStatus::ready) {
      const auto current = static_cast<std::uint64_t>(frame + 1);
      if (emitted > current || current - emitted >= lag_counts.size()) { failed = true; break; }
      ++lag_counts[current - emitted]; ++ready;
    }
    else if (status == GuardStatus::buffering) ++buffering;
    else if (status == GuardStatus::underrun) ++underruns;
    else { ++overloads; break; }
    for (float sample : pcm) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    next += std::chrono::milliseconds(10); std::this_thread::sleep_until(next);
  }
  const auto final_state = runtime.Snapshot().state;
  const bool closed = runtime.Shutdown();
  unsigned cumulative = 0, p95_frames = 0, max_frames = 0;
  bool p95_set = false;
  for (unsigned i = 0; i < lag_counts.size(); ++i) {
    cumulative += lag_counts[i];
    if (lag_counts[i]) max_frames = i;
    if (ready && !p95_set && cumulative * 100 >= ready * 95) { p95_frames = i; p95_set = true; }
  }
  const bool ok = !failed && closed && !overloads && ready > 0 && peak > 0.0001 && final_state == LifecycleState::active;
  std::printf("threaded_native=%s startup_frames=%lu ready=%u buffering=%u underruns=%u overloads=%u p95_frame_lag=%u max_frame_lag=%u\n",
              ok ? "SMOKE_COMPLETED" : "FAIL", delay, ready, buffering, underruns, overloads, p95_frames, max_frames);
  FreeLibrary(dll);
  return ok ? 0 : 1;
}
