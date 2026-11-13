// Isolated synthetic worker experiment; this is not a production audio callback.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/worker_step/worker.h"
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/capture_bridge/bridge.h"
#include "research_engine.h"
#define NOMINMAX
#include <windows.h>
#include <atomic>
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
  CaptureBridge<8> bridge(delay);
  WorkerStep<ResearchEngine, 8> step(engine);
  std::atomic<bool> stop{false}, failed{false};
  std::atomic<unsigned> processed{0};
  float pcm[480]{};
  if (bridge.Capture(pcm, 480, 480, 48000, 1, 1, false) != (delay ? ExchangeStatus::buffering : ExchangeStatus::no_frame)) {
    FreeLibrary(dll); return 5;
  }
  std::thread worker([&] {
    while (!stop.load()) {
      const auto status = step.Run(bridge.WorkerExchange(), 1);
      if (status == WorkerStatus::processed) ++processed;
      else if (status != WorkerStatus::idle) { failed.store(true); break; }
      else std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    if (!engine.Close()) failed.store(true);
  });
  const auto deadline = Clock::now() + std::chrono::seconds(20);
  while (!processed.load() && !failed.load() && Clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  unsigned ready = 0, buffering = 0, underruns = 0, overloads = 0;
  std::array<unsigned, 32> lag_counts{};
  double peak = 0;
  auto next = Clock::now();
  for (int frame = 0; frame < 300 && processed.load() && !failed.load(); ++frame) {
    for (int i = 0; i < 480; ++i) pcm[i] = 6553.6f * std::sin((frame * 480 + i) * 0.05f);
    std::uint64_t emitted;
    const auto status = bridge.Capture(pcm, 480, 480, 48000, 1, 1, false, &emitted);
    if (status == ExchangeStatus::ready) {
      const auto current = static_cast<std::uint64_t>(frame + 1);
      if (emitted > current || current - emitted >= lag_counts.size()) { failed.store(true); break; }
      ++lag_counts[current - emitted]; ++ready;
    }
    else if (status == ExchangeStatus::buffering) ++buffering;
    else if (status == ExchangeStatus::no_frame) ++underruns;
    else { ++overloads; break; }
    for (float sample : pcm) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    next += std::chrono::milliseconds(10); std::this_thread::sleep_until(next);
  }
  stop.store(true); worker.join();
  unsigned cumulative = 0, p95_frames = 0, max_frames = 0;
  bool p95_set = false;
  for (unsigned i = 0; i < lag_counts.size(); ++i) {
    cumulative += lag_counts[i];
    if (lag_counts[i]) max_frames = i;
    if (ready && !p95_set && cumulative * 100 >= ready * 95) { p95_frames = i; p95_set = true; }
  }
  const bool ok = !failed.load() && !overloads && ready > 0 && peak > 0.0001;
  std::printf("threaded_native=%s startup_frames=%lu ready=%u buffering=%u underruns=%u overloads=%u processed=%u p95_frame_lag=%u max_frame_lag=%u\n",
              ok ? "SMOKE_COMPLETED" : "FAIL", delay, ready, buffering, underruns, overloads, processed.load(), p95_frames, max_frames);
  FreeLibrary(dll);
  return ok ? 0 : 1;
}
