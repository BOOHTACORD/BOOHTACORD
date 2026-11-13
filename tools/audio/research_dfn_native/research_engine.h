#ifndef BOOHTA_DFN_RESEARCH_ENGINE_H_
#define BOOHTA_DFN_RESEARCH_ENGINE_H_
#include "../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/frame_queue/queue.h"
#include <algorithm>
#include <cstring>

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
  bool Process(boohta::deepfilter::AudioFrame& frame) {
    float result[480]{};
    if (!state || process(state, frame.samples.data(), result, 480) != 0) return false;
    std::copy_n(result, 480, frame.samples.data()); return true;
  }
  bool Close() { if (!state) return true; const bool ok = free_state(state) == 0; state = nullptr; return ok; }
};
#endif
