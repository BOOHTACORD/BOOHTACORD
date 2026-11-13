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
  if (!pcm || frames != 480 || capacity < frames || rate_.load() != 48000 || channels_.load() != 1)
    return fail(Failure::kFormat);
  float work[480];
  std::copy_n(pcm, 480, work);
  const auto status = hook_->Capture(work, frames, capacity, rate_.load(), channels_.load());
  using deepfilter::GuardStatus;
  if (status == GuardStatus::muted || status == GuardStatus::stale) {
    controls.Reset();
    std::fill_n(pcm, 480, 0.f); return true;
  }
  if (status == GuardStatus::underrun) return fail(Failure::kUnderrun);
  if (status == GuardStatus::invalid_format) return fail(Failure::kFormat);
  if (status == GuardStatus::fallback) return fail(Failure::kProcessor);
  if (status == GuardStatus::buffering) {
    std::fill_n(pcm, 480, 0.f); return true;
  }
  for (float sample : work)
    if (!std::isfinite(sample) || std::fabs(sample) > 32768.f) return fail(Failure::kNonFinite);
  if (generation != generation_.load() || requested_.load() != Engine::kDeepFilter) {
    controls.Reset();
    std::fill_n(pcm, 480, 0.f); return true;
  }
  std::copy_n(work, 480, pcm);
  failure_.store(Failure::kNone);
  processed_.fetch_add(1);
  return true;
}
}  // namespace boohta
