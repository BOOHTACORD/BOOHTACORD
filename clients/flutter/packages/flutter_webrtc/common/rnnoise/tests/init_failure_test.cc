#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <string>
void fail_init(bool value);
int processed_calls();
int main() {
  using Processor = boohta::RnnoiseCaptureProcessor;
  fail_init(true);
  const int before = processed_calls();
  Processor capture;
  capture.Initialize(48000, 1);
  capture.SetEngine(Processor::Engine::kRnnoise);
  std::array<float, 480> frame;
  frame.fill(100.f);
  assert(!capture.supported());
  assert(!capture.Process(frame.data(), 480, 480));
  assert(processed_calls() == before);
  for (float sample : frame) assert(sample == 100.f);
  assert(capture.EffectiveEngine() == Processor::Engine::kUnknown);
  assert(std::string(capture.failure_reason()) == "processor-unavailable");
  fail_init(false);
  capture.Reset();
  assert(!capture.Process(frame.data(), 480, 480));
  assert(processed_calls() == before);
  assert(!capture.supported());
  Processor restarted;
  restarted.Initialize(48000, 1);
  restarted.SetEngine(Processor::Engine::kRnnoise);
  assert(restarted.Process(frame.data(), 480, 480));
  assert(restarted.supported());
  assert(restarted.EffectiveEngine() == Processor::Engine::kRnnoise);
  fail_init(true);
  restarted.Reset();
  const int after = processed_calls();
  assert(!restarted.Process(frame.data(), 480, 480));
  assert(processed_calls() == after);
  assert(!restarted.supported());
  fail_init(false);
  restarted.Reset();
  assert(restarted.Process(frame.data(), 480, 480));
}
