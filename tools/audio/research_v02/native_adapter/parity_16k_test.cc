#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <limits>

static void* noMemory(size_t) { return nullptr; }
extern "C" void rnnoise_test_after_frame(void (*callback)());
static boohta::RnnoiseCaptureProcessor* race_capture;
static void disableDuringFrame() {
  race_capture->SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kOff);
}

int main() {
  boohta::RnnoiseCaptureProcessor capture;
  capture.Initialize(16000, 1);
  capture.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  auto* direct = static_cast<DenoiseState*>(std::malloc(rnnoise_get_size()));
  assert(direct && rnnoise_init(direct) == 0);
  boohta::deepfilter::Resampler16k resampler;
  std::array<float, 160> source{}, actual{}, expected{};
  std::array<float, 480> upsampled{}, filtered{};
  bool changed = false;
  for (int frame = 0; frame < 100; ++frame) {
    for (int i = 0; i < 160; ++i)
      source[i] = 5000.f * std::sin((frame * 160 + i) * .073f);
    actual = source;
    resampler.Upsample(source.data(), upsampled.data());
    rnnoise_process_frame(direct, filtered.data(), upsampled.data());
    resampler.Downsample(filtered.data(), expected.data());
    assert(capture.Process(actual.data(), 160, 160));
    for (int i = 0; i < 160; ++i) {
      assert(std::isfinite(actual[i]));
      assert(std::fabs(actual[i] - expected[i]) < 0.001f);
      changed = changed || std::fabs(actual[i] - source[i]) > 0.1f;
    }
  }
  assert(changed && capture.processed_frames() == 100);
  actual = source;
  assert(!capture.Process(actual.data(), 160, 159));
  for (int i = 0; i < 159; ++i) assert(actual[i] == 0.f);
  assert(actual[159] == source[159]);
  actual[10] = std::numeric_limits<float>::quiet_NaN();
  assert(!capture.Process(actual.data(), 160, 160));
  for (float value : actual) assert(value == 0.f);
  boohta::RnnoiseCaptureProcessor unavailable(noMemory);
  unavailable.Initialize(16000, 1);
  unavailable.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  actual = source;
  assert(!unavailable.Process(actual.data(), 160, 160));
  for (float value : actual) assert(value == 0.f);
  boohta::RnnoiseCaptureProcessor race;
  race.Initialize(16000, 1);
  race.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  race_capture = &race;
  rnnoise_test_after_frame(disableDuringFrame);
  actual = source;
  assert(race.Process(actual.data(), 160, 160));
  for (float value : actual) assert(value == 0.f);
  assert(race.EffectiveEngine() == boohta::RnnoiseCaptureProcessor::Engine::kOff);
  rnnoise_destroy(direct);
}
