#ifndef BOOHTA_DEEPFILTER_FRAME_QUEUE_H_
#define BOOHTA_DEEPFILTER_FRAME_QUEUE_H_

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>

namespace boohta::deepfilter {
struct AudioFrame {
  std::array<float, 480> samples{};
  std::uint64_t generation = 0;
  std::uint64_t sequence = 0;
};

// Exactly one producer and one consumer. Reset by changing generations, not
// by mutating the queue concurrently. Full/empty are immediate, never waits.
template <std::size_t Capacity>
class FrameQueue {
  static_assert(Capacity > 0);
  static_assert(std::atomic<std::size_t>::is_always_lock_free);
 public:
  bool TryPush(const AudioFrame& frame) noexcept {
    const auto head = head_.load(std::memory_order_relaxed);
    const auto next = (head + 1) % (Capacity + 1);
    if (next == tail_.load(std::memory_order_acquire)) return false;
    slots_[head] = frame;
    head_.store(next, std::memory_order_release);
    return true;
  }

  bool TryPop(AudioFrame& frame) noexcept {
    const auto tail = tail_.load(std::memory_order_relaxed);
    if (tail == head_.load(std::memory_order_acquire)) return false;
    frame = slots_[tail];
    tail_.store((tail + 1) % (Capacity + 1), std::memory_order_release);
    return true;
  }

 private:
  std::array<AudioFrame, Capacity + 1> slots_{};
  alignas(64) std::atomic<std::size_t> head_{0};
  alignas(64) std::atomic<std::size_t> tail_{0};
};
}  // namespace boohta::deepfilter
#endif
