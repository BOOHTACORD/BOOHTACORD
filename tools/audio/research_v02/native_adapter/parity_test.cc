#include "rnnoise_capture_processor.h"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdlib>

extern "C" int rnnoise_get_frame_size();

int main() {
  assert(rnnoise_get_frame_size() == 480);  // This symbol is specific to v0.2.
  boohta::RnnoiseCaptureProcessor capture;
  capture.Initialize(48000, 1);
  capture.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  auto* direct = static_cast<DenoiseState*>(std::malloc(rnnoise_get_size()));
  assert(direct && rnnoise_init(direct) == 0);
  std::array<float, 480> source{}, actual{}, expected{};
  bool changed = false;
  for (int frame = 0; frame < 100; ++frame) {
    for (int i = 0; i < 480; ++i)
      source[i] = 5000.f * std::sin((frame * 480 + i) * .037f);
    actual = source;
    rnnoise_process_frame(direct, expected.data(), source.data());
    assert(capture.Process(actual.data(), 480, 480));
    for (int i = 0; i < 480; ++i) {
      assert(std::isfinite(actual[i]));
      assert(std::fabs(actual[i] - expected[i]) < 0.001f);
      changed = changed || std::fabs(actual[i] - source[i]) > 0.1f;
    }
  }
  assert(changed && capture.processed_frames() == 100);
  rnnoise_destroy(direct);
}
