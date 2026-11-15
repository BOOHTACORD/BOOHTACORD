#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <cmath>
#include <string>

int main() {
  using Processor = boohta::RnnoiseCaptureProcessor;
  assert(std::string(Processor::ModelId()) == "rnnoise-release-v0.2");
  Processor processor;
  processor.Initialize(48000, 1);
  processor.SetEngine(Processor::Engine::kRnnoise);
  std::array<float, 480> frame{};
  for (int step = 0; step < 100; ++step) {
    for (int index = 0; index < 480; ++index)
      frame[index] = 3000.f * std::sin((step * 480 + index) * .17f);
    assert(processor.Process(frame.data(), 480, 480));
    for (float value : frame) assert(std::isfinite(value) && std::fabs(value) <= 32768.f);
  }
  assert(processor.processed_frames() == 100);
  assert(processor.fallback_frames() == 0);
  assert(processor.EffectiveEngine() == Processor::Engine::kRnnoise);
  processor.SetEngine(Processor::Engine::kOff);
  frame.fill(123.f);
  assert(!processor.Process(frame.data(), 480, 480));
  for (float value : frame) assert(value == 123.f);
}
