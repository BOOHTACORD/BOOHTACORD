#ifndef BOOHTA_DEEPFILTER_CAPTURE_GUARD_H_
#define BOOHTA_DEEPFILTER_CAPTURE_GUARD_H_

#include "../capture_bridge/bridge.h"
#include "../lifecycle/lifecycle.h"
#include <algorithm>

namespace boohta::deepfilter {
enum class GuardStatus { ready, buffering, underrun, fallback, muted, stale, invalid_format };

// One capture thread. The owner must serialize the final publication decision
// with mute intent; a snapshot cannot close a race after this method returns.
// On fallback the original PCM remains available to the owning policy.
template <typename Bridge>
class CaptureGuard {
 public:
  CaptureGuard(Lifecycle& lifecycle, Bridge& bridge) noexcept : lifecycle_(lifecycle), bridge_(bridge) {}
  GuardStatus Process(float* pcm, int frames, int capacity, int rate, int channels,
                      std::uint64_t* emitted_sequence = nullptr) noexcept {
    if (emitted_sequence) *emitted_sequence = std::numeric_limits<std::uint64_t>::max();
    const auto before = lifecycle_.Snapshot();
    if (!pcm || frames != 480 || capacity < frames || rate != 48000 || channels != 1) {
      lifecycle_.Fail(before.generation);
      return GuardStatus::invalid_format;
    }
    if (before.state == LifecycleState::muted) {
      std::fill_n(pcm, 480, 0.f); return GuardStatus::muted;
    }
    if (!Running(before.state)) return GuardStatus::fallback;
    float work[480];
    std::copy_n(pcm, 480, work);
    std::uint64_t sequence = std::numeric_limits<std::uint64_t>::max();
    const auto result = bridge_.Capture(work, 480, 480, rate, channels, before.generation, false, &sequence);
    const auto after = lifecycle_.Snapshot();
    if (after.generation != before.generation || !Running(after.state)) {
      std::fill_n(pcm, 480, 0.f); return GuardStatus::stale;
    }
    if (result == ExchangeStatus::invalid_audio || result == ExchangeStatus::overload) {
      if (!lifecycle_.Fail(before.generation)) {
        std::fill_n(pcm, 480, 0.f); return GuardStatus::stale;
      }
      return GuardStatus::fallback;
    }
    std::copy_n(work, 480, pcm);
    if (emitted_sequence) *emitted_sequence = sequence;
    if (result == ExchangeStatus::ready) return GuardStatus::ready;
    return result == ExchangeStatus::buffering ? GuardStatus::buffering : GuardStatus::underrun;
  }
 private:
  static bool Running(LifecycleState state) noexcept {
    return state == LifecycleState::starting || state == LifecycleState::active;
  }
  Lifecycle& lifecycle_;
  Bridge& bridge_;
};
}  // namespace boohta::deepfilter
#endif
