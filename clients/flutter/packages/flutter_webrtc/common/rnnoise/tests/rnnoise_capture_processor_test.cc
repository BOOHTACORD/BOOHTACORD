#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <cmath>
#include <limits>
#include <string>
using boohta::RnnoiseCaptureProcessor;
static void* NoMemory(size_t) { return nullptr; }
int main() {
  RnnoiseCaptureProcessor unavailable(NoMemory);
  unavailable.SetEngine(RnnoiseCaptureProcessor::Engine::kRnnoise);
  unavailable.Initialize(48000, 1);
  std::array<float, 480> untouched{};
  assert(!unavailable.supported());
  assert(!unavailable.Process(untouched.data(), 480, 480));
  assert(unavailable.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kUnknown);
  assert(std::string(unavailable.failure_reason()) == "processor-unavailable");
  RnnoiseCaptureProcessor processor;
  std::array<float, 480> frame;
  for (int i = 0; i < 480; ++i) frame[i] = 5000.f * std::sin(i * .17f);
  const auto original = frame;
  processor.Initialize(48000, 1);
  assert(!processor.Process(frame.data(), 480, 480));
  assert(frame == original);
  processor.SetEngine(RnnoiseCaptureProcessor::Engine::kRnnoise);
  assert(processor.EffectiveEngine() != RnnoiseCaptureProcessor::Engine::kRnnoise);
  assert(processor.Process(frame.data(), 480, 480));
  assert(frame != original);
  assert(processor.processed_frames() == 1);
  for (float value : frame) assert(std::isfinite(value));
  processor.Reset(); frame = original;
  assert(processor.Process(frame.data(), 480, 480));
  RnnoiseCaptureProcessor fresh;
  fresh.Initialize(48000, 1);
  fresh.SetEngine(RnnoiseCaptureProcessor::Engine::kRnnoise);
  auto comparison = original;
  assert(fresh.Process(comparison.data(), 480, 480));
  assert(frame == comparison);
  processor.Initialize(16000, 1); frame = original;
#ifdef BOOHTA_RNNOISE_V02_RESEARCH
  assert(processor.Process(frame.data(), 160, 160));
  assert(frame != original);
  assert(processor.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kRnnoise);
  frame = original;
#else
  assert(!processor.Process(frame.data(), 160, 160));
  assert(frame == original);
  assert(processor.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kUnknown);
#endif
  processor.Initialize(48000, 2);
  assert(!processor.Process(frame.data(), 480, 480));
  assert(frame == original);
  processor.Initialize(48000, 1);
  assert(!processor.Process(frame.data(), 480, 479));
  frame[10] = std::numeric_limits<float>::quiet_NaN();
  assert(!processor.Process(frame.data(), 480, 480));
  assert(std::isnan(frame[10]));
  processor.SetEngine(RnnoiseCaptureProcessor::Engine::kOff);
  assert(processor.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kOff);
  assert(!processor.Process(nullptr, 480, 480));
}
