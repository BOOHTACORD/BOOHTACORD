#include "resampler.h"
#include "../../rnnoise_capture_processor.h"
#include "../capture_hook/interface.h"
#include <cassert>
#include <cmath>
#include <limits>
using namespace boohta;
using namespace boohta::deepfilter;
struct HalfHook final : CaptureHook {
  HookReadiness readiness = HookReadiness::ready;
  int calls = 0;
  void Reset(bool) noexcept override {}
  bool Available() const noexcept override { return true; }
  HookReadiness Readiness() const noexcept override { return readiness; }
  GuardStatus Capture(float* pcm, int frames, int capacity, int rate, int channels) noexcept override {
    ++calls;
    assert(frames == 480 && capacity == 480 && rate == 48000 && channels == 1);
    for (int i = 0; i < frames; ++i) pcm[i] *= .5f;
    return GuardStatus::ready;
  }
};
int main() {
  Resampler16k resampler;
  float input[160], wide[480], output[160];
  for (float& value : input) value = 4000.f;
  for (int frame = 0; frame < 4; ++frame) {
    resampler.Upsample(input, wide);
    resampler.Downsample(wide, output);
  }
  for (float value : output) assert(std::fabs(value - 4000.f) < 5.f);
  double input_energy = 0, output_energy = 0;
  for (int frame = 0; frame < 12; ++frame) {
    for (int i = 0; i < 160; ++i) input[i] = 4000.f * std::sin((frame * 160 + i) * 2 * 3.141592653589793 * 6000 / 16000);
    resampler.Upsample(input, wide); resampler.Downsample(wide, output);
    if (frame > 1) for (int i = 0; i < 160; ++i) {
      input_energy += input[i] * input[i]; output_energy += output[i] * output[i];
    }
  }
  assert(std::sqrt(output_energy / input_energy) > 0.9);
  resampler.Reset();
  input_energy = 0; output_energy = 0;
  for (int frame = 0; frame < 12; ++frame) {
    for (int i = 0; i < 480; ++i) wide[i] = 4000.f * std::sin((frame * 480 + i) * 2 * 3.141592653589793 * 10000 / 48000);
    resampler.Downsample(wide, output);
    if (frame > 1) {
      for (float value : output) output_energy += value * value;
      input_energy += 160.0 * 4000.0 * 4000.0 / 2;
    }
  }
  assert(std::sqrt(output_energy / input_energy) < 0.02);
  resampler.Reset();
  for (int i = 0; i < 160; ++i) input[i] = i < 80 ? -32768.f : 32768.f;
  resampler.Upsample(input, wide);
  for (float value : wide) assert(std::isfinite(value) && std::fabs(value) <= 32768.f);
  resampler.Reset();
  for (float& value : input) value = 0.f;
  resampler.Upsample(input, wide); resampler.Downsample(wide, output);
  for (float value : output) assert(value == 0.f);
  HalfHook hook;
  RnnoiseCaptureProcessor processor(std::malloc, &hook);
  processor.Initialize(16000, 1);
  processor.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
  hook.readiness = HookReadiness::preparing;
  for (float& value : input) value = 4000.f;
  assert(processor.Process(input, 160, 160));
  for (float value : input) assert(value == 0.f);
  assert(hook.calls == 0 && processor.processed_frames() == 0);
  hook.readiness = HookReadiness::ready;
  for (int n = 0; n < 4; ++n) {
    for (float& value : input) value = 4000.f;
    assert(processor.Process(input, 160, 160));
  }
  for (float value : input) assert(std::fabs(value - 2000.f) < 3.f);
  assert(processor.processed_frames() == 4 && processor.fallback_frames() == 0);
  assert(processor.sample_rate() == 16000 && processor.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kDeepFilter);
  const int previous_calls = hook.calls;
  input[0] = std::numeric_limits<float>::quiet_NaN();
  assert(!processor.Process(input, 160, 160));
  assert(hook.calls == previous_calls && processor.fallback_frames() == 1);
}
