#include "rnnoise_capture_processor.h"
#include <algorithm>
#include <array>
#include <cmath>

namespace boohta {
bool RnnoiseCaptureProcessor::ProcessResearchV02At16k(float* pcm, int frames, int capacity, uint64_t generation) {
  const auto fail = [&](Failure reason) {
    if (generation == generation_.load() && requested_.load() == Engine::kRnnoise) failure_.store(reason);
    fallback_.fetch_add(1);
    if (pcm && frames > 0 && capacity > 0) std::fill_n(pcm, std::min(frames, capacity), 0.f);
    resampler_.Reset();
    if (state_) rnnoise_init(state_);
    return false;
  };
  if (!state_) return fail(Failure::kUnavailable);
  if (!pcm || channels_.load() != 1 || frames != 160 || capacity < frames) return fail(Failure::kFormat);
  for (int i = 0; i < frames; ++i)
    if (!std::isfinite(pcm[i]) || std::fabs(pcm[i]) > 32768.f) return fail(Failure::kNonFinite);
  std::array<float, 480> work{};
  resampler_.Upsample(pcm, work.data());
  rnnoise_process_frame(state_, work.data(), work.data());
  for (float sample : work)
    if (!std::isfinite(sample) || std::fabs(sample) > 32768.f) return fail(Failure::kNonFinite);
  if (generation != generation_.load() || requested_.load() != Engine::kRnnoise) {
    controls.Reset(); resampler_.Reset(); std::fill_n(pcm, frames, 0.f); return true;
  }
  resampler_.Downsample(work.data(), pcm);
  failure_.store(Failure::kNone);
  processed_.fetch_add(1);
  return true;
}
}
