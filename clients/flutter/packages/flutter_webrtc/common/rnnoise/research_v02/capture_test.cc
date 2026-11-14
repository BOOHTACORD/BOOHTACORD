#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <cmath>
#include <limits>

int main() {
  boohta::RnnoiseCaptureProcessor processor;
  processor.Initialize(16000, 1);
  processor.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  std::array<float, 160> frame{};
  bool changed = false;
  for (int n = 0; n < 100; ++n) {
    for (int i = 0; i < 160; ++i) frame[i] = 5000.f * std::sin((n * 160 + i) * .073f);
    const auto input = frame;
    assert(processor.Process(frame.data(), 160, 160));
    for (int i = 0; i < 160; ++i) {
      assert(std::isfinite(frame[i]));
      changed |= std::fabs(frame[i] - input[i]) > .1f;
    }
  }
  assert(changed && processor.processed_frames() == 100);
  assert(processor.EffectiveEngine() == boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  frame[10] = std::numeric_limits<float>::quiet_NaN();
  assert(!processor.Process(frame.data(), 160, 160));
  for (float sample : frame) assert(sample == 0.f);
}
