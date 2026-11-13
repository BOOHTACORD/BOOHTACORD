#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <string>

extern "C" void rnnoise_test_fail_initialization(int fail);
extern "C" int rnnoise_test_processed_frames();
int main() {
  using Processor = boohta::RnnoiseCaptureProcessor;
  rnnoise_test_fail_initialization(1);
  const int before = rnnoise_test_processed_frames();
  Processor capture;
  capture.Initialize(16000, 1);
  capture.SetEngine(Processor::Engine::kRnnoise);
  std::array<float, 160> frame;
  frame.fill(500.f);
  assert(!capture.supported());
  assert(!capture.Process(frame.data(), 160, 160));
  assert(rnnoise_test_processed_frames() == before);
  for (float value : frame) assert(value == 0.f);
  assert(capture.EffectiveEngine() == Processor::Engine::kUnknown);
  assert(std::string(capture.failure_reason()) == "processor-unavailable");
  rnnoise_test_fail_initialization(0);
  capture.Reset();
  frame.fill(500.f);
  assert(capture.Process(frame.data(), 160, 160));
  assert(capture.supported());
  assert(capture.EffectiveEngine() == Processor::Engine::kRnnoise);
  rnnoise_test_fail_initialization(1);
  capture.Reset();
  frame.fill(500.f);
  assert(!capture.Process(frame.data(), 160, 160));
  for (float value : frame) assert(value == 0.f);
  assert(!capture.supported());
  assert(capture.EffectiveEngine() == Processor::Engine::kUnknown);
  rnnoise_test_fail_initialization(0);
  capture.Reset();
  assert(capture.Process(frame.data(), 160, 160));
  rnnoise_test_fail_initialization(1);
  capture.Initialize(48000, 1);
  std::array<float, 480> fullband;
  fullband.fill(500.f);
  const int before_fullband = rnnoise_test_processed_frames();
  assert(!capture.Process(fullband.data(), 480, 480));
  assert(rnnoise_test_processed_frames() == before_fullband);
  for (float value : fullband) assert(value == 500.f);
  rnnoise_test_fail_initialization(0);
}
