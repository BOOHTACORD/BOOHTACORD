// Explicitly invoked Windows research probe; not linked into the client.
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/worker_step/worker.h"
#define NOMINMAX
#include <windows.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>

using namespace boohta::deepfilter;
using Create = int (*)(const unsigned char*, std::size_t, void**);
using Process = int (*)(void*, const float*, float*, std::size_t);
using Free = int (*)(void*);

struct ResearchEngine {
  Create create; Process process; Free free_state;
  const char* model; void* state = nullptr;
  bool Reset() {
    void* previous = state; state = nullptr;
    if (previous && free_state(previous) != 0) return false;
    return create(reinterpret_cast<const unsigned char*>(model), std::strlen(model), &state) == 0 && state;
  }
  bool Process(AudioFrame& frame) {
    float result[480]{};
    if (!state || process(state, frame.samples.data(), result, 480) != 0) return false;
    std::copy_n(result, 480, frame.samples.data()); return true;
  }
  bool Close() { if (!state) return true; const bool ok = free_state(state) == 0; state = nullptr; return ok; }
};

int main(int argc, char** argv) {
  if (argc != 3) return 2;
  HMODULE dll = LoadLibraryExA(argv[1], nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (!dll) return 3;
  auto create = reinterpret_cast<Create>(GetProcAddress(dll, "research_create"));
  auto process = reinterpret_cast<Process>(GetProcAddress(dll, "research_process"));
  auto free_state = reinterpret_cast<Free>(GetProcAddress(dll, "research_free"));
  if (!create || !process || !free_state) { FreeLibrary(dll); return 4; }
  ResearchEngine engine{create, process, free_state, argv[2]};
  FrameExchange<4> exchange;
  WorkerStep<ResearchEngine, 4> worker(engine);
  float input[480]{}, output[480]{};
  double peak = 0;
  bool ok = true;
  for (int frame = 0; frame < 220 && ok; ++frame) {
    for (int i = 0; i < 480; ++i) input[i] = 0.2f * std::sin((frame * 480 + i) * 0.05f);
    const auto status = exchange.Capture(input, 1, false, output);
    ok = status == (frame ? ExchangeStatus::ready : ExchangeStatus::no_frame);
    for (float value : output) peak = std::max(peak, static_cast<double>(std::fabs(value)));
    ok = ok && worker.Run(exchange, 1) == WorkerStatus::processed;
  }
  ok = ok && peak > 0.0001;
  if (ok) {
    ok = exchange.Capture(input, 2, true, output) == ExchangeStatus::no_frame;
    for (float value : output) ok = ok && value == 0.0f;
    ok = ok && exchange.Capture(input, 3, false, output) == ExchangeStatus::no_frame;
    ok = ok && worker.Run(exchange, 3) == WorkerStatus::processed;
    ok = ok && exchange.Capture(input, 3, false, output) == ExchangeStatus::ready;
  }
  ok = engine.Close() && ok;
  FreeLibrary(dll);
  std::printf("research_native_worker=%s frames=220\n", ok ? "PASS" : "FAIL");
  return ok ? 0 : 1;
}
