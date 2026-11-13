#ifndef BOOHTA_DEEPFILTER_LIFECYCLE_H_
#define BOOHTA_DEEPFILTER_LIFECYCLE_H_

#include <atomic>
#include <cstdint>
#include <limits>

namespace boohta::deepfilter {
enum class LifecycleState : std::uint64_t { stopped, starting, active, muted, failed };
struct LifecycleSnapshot { std::uint64_t generation; LifecycleState state; };

// Only status and generation are synchronized here. The owner must stop/join
// its worker before destruction and synchronize mute with actual publication.
class Lifecycle {
 public:
  static_assert(std::atomic<std::uint64_t>::is_always_lock_free, "capture state must be lock-free");
  LifecycleSnapshot Snapshot() const noexcept { return Decode(word_.load(std::memory_order_acquire)); }
  std::uint64_t Start() noexcept { return Next(LifecycleState::starting); }
  std::uint64_t Mute() noexcept { return Next(LifecycleState::muted); }
  std::uint64_t Stop() noexcept { return Next(LifecycleState::stopped); }
  bool Activate(std::uint64_t generation) noexcept {
    if (!generation || generation > kMaxGeneration) return false;
    auto expected = Encode(generation, LifecycleState::starting);
    return word_.compare_exchange_strong(expected, Encode(generation, LifecycleState::active),
                                         std::memory_order_acq_rel);
  }
  bool Fail(std::uint64_t generation) noexcept {
    auto current = word_.load(std::memory_order_acquire);
    for (;;) {
      auto state = Decode(current);
      if (state.generation != generation ||
          (state.state != LifecycleState::starting && state.state != LifecycleState::active)) return false;
      if (word_.compare_exchange_weak(current, Encode(generation, LifecycleState::failed),
                                      std::memory_order_acq_rel)) return true;
    }
  }

 private:
  static constexpr unsigned kStateBits = 3;
  static constexpr std::uint64_t kMaxGeneration = std::numeric_limits<std::uint64_t>::max() >> kStateBits;
  static std::uint64_t Encode(std::uint64_t generation, LifecycleState state) noexcept {
    return (generation << kStateBits) | static_cast<std::uint64_t>(state);
  }
  static LifecycleSnapshot Decode(std::uint64_t word) noexcept {
    return {word >> kStateBits, static_cast<LifecycleState>(word & 7)};
  }
  std::uint64_t Next(LifecycleState state) noexcept {
    auto current = word_.load(std::memory_order_acquire);
    for (;;) {
      const auto previous = Decode(current).generation;
      const bool exhausted = previous == kMaxGeneration;
      const auto generation = exhausted ? previous : previous + 1;
      const auto target = Encode(generation, exhausted ? LifecycleState::failed : state);
      if (word_.compare_exchange_weak(current, target, std::memory_order_acq_rel))
        return exhausted ? 0 : generation;
    }
  }
  std::atomic<std::uint64_t> word_{Encode(0, LifecycleState::stopped)};
};
}  // namespace boohta::deepfilter
#endif
