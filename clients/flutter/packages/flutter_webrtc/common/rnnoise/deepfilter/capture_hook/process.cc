#include "../../rnnoise_capture_processor.h"
#include "interface.h"
#include <algorithm>
#include <cmath>

namespace boohta {
bool RnnoiseCaptureProcessor::supported() const {
  return requested_.load() == Engine::kDeepFilter ? hook_ && hook_->Available() : state_ != nullptr;
}

bool RnnoiseCaptureProcessor::ProcessDeepFilter(float* pcm, int frames, int capacity, uint64_t generation) {
  const auto fail = [&](Failure reason) {
    if (generation == generation_.load() && requested_.load() == Engine::kDeepFilter)
      failure_.store(reason);
    fallback_.fetch_add(1);
    return false;
  };
  if (!hook_ || !hook_->Available()) return fail(Failure::kUnavailable);
  const bool convert = rate_.load() == 16000 && frames == 160;
  if (!pcm || capacity < frames || channels_.load() != 1 ||
      (!convert && (rate_.load() != 48000 || frames != 480))) return fail(Failure::kFormat);
  for (int i = 0; i < frames; ++i)
    if (!std::isfinite(pcm[i]) || std::fabs(pcm[i]) > 32768.f) return fail(Failure::kNonFinite);
  const auto readiness = hook_->Readiness();
  if (readiness == deepfilter::HookReadiness::preparing) {
    resampler_.Reset();
    std::fill_n(pcm, frames, 0.f); return true;
  }
  if (readiness == deepfilter::HookReadiness::failed) return fail(Failure::kProcessor);
  float work[480];
  if (convert) resampler_.Upsample(pcm, work); else std::copy_n(pcm, 480, work);
  const auto status = hook_->Capture(work, 480, 480, 48000, 1);
  using deepfilter::GuardStatus;
  if (status == GuardStatus::muted || status == GuardStatus::stale) {
    controls.Reset();
    resampler_.Reset();
    std::fill_n(pcm, frames, 0.f); return true;
  }
  if (status == GuardStatus::underrun) return fail(Failure::kUnderrun);
  if (status == GuardStatus::invalid_format) return fail(Failure::kFormat);
  if (status == GuardStatus::fallback) return fail(Failure::kProcessor);
  if (status == GuardStatus::buffering) {
    std::fill_n(pcm, frames, 0.f); return true;
  }
  for (float sample : work)
    if (!std::isfinite(sample) || std::fabs(sample) > 32768.f) return fail(Failure::kNonFinite);
  if (generation != generation_.load() || requested_.load() != Engine::kDeepFilter) {
    controls.Reset();
    resampler_.Reset();
    std::fill_n(pcm, frames, 0.f); return true;
  }
  if (convert) resampler_.Downsample(work, pcm); else std::copy_n(work, 480, pcm);
  failure_.store(Failure::kNone);
  processed_.fetch_add(1);
  return true;
}
}  // namespace boohta
