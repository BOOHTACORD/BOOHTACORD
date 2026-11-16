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
  // Android JNI indexes its legacy OFF/WebRTC/RNNoise/UNKNOWN table.
  assert(static_cast<int>(processor.EffectiveEngine()) == 3);
  assert(std::string(processor.failure_reason()) == "awaiting-audio");
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
  // Android's capture post-processor can provide mono 10 ms frames at 16 kHz.
  RnnoiseCaptureProcessor android(std::malloc, nullptr, true);
  android.Initialize(16000, 1);
  android.SetEngine(RnnoiseCaptureProcessor::Engine::kRnnoise);
  auto short_frame = original;
  assert(android.Process(short_frame.data(), 160, 160));
  assert(short_frame != original);
  assert(android.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kRnnoise);
  assert(android.processed_frames() == 1);
  android.Reset();
  short_frame = original;
  assert(android.Process(short_frame.data(), 160, 160));
  RnnoiseCaptureProcessor fresh_android(std::malloc, nullptr, true);
  fresh_android.Initialize(16000, 1);
  fresh_android.SetEngine(RnnoiseCaptureProcessor::Engine::kRnnoise);
  auto fresh_frame = original;
  assert(fresh_android.Process(fresh_frame.data(), 160, 160));
  assert(short_frame == fresh_frame);
  short_frame[3] = std::numeric_limits<float>::quiet_NaN();
  assert(!android.Process(short_frame.data(), 160, 160));
  assert(std::string(android.failure_reason()) == "invalid-audio-samples");
#ifdef BOOHTA_RNNOISE_V02_RESEARCH
  // The Windows v0.2 path deliberately mutes invalid input.
  for (int i = 0; i < 160; ++i) assert(short_frame[i] == 0.f);
#else
  // The Android v0.1 path leaves fallback handling to its caller.
  assert(std::isnan(short_frame[3]));
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
