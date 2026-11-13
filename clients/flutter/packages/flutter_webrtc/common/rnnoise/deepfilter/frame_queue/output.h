#ifndef BOOHTA_DEEPFILTER_FRAME_OUTPUT_H_
#define BOOHTA_DEEPFILTER_FRAME_OUTPUT_H_

#include "queue.h"
#include <cmath>

namespace boohta::deepfilter {
enum class FrameStatus { ready, no_frame, invalid_audio };
// The consumer serializes mute and generation changes with this call. This
// helper alone cannot guard a mute racing with later publication of its result.
// Drain at most Capacity slots; underflow and rejected frames output silence.
template <std::size_t Capacity>
FrameStatus TakeCurrentFrame(FrameQueue<Capacity>& queue, std::uint64_t generation,
                      bool muted, bool has_last, std::uint64_t last_sequence,
                      AudioFrame& output) noexcept {
  output = AudioFrame{};
  AudioFrame candidate{};
  for (std::size_t i = 0; i < Capacity && queue.TryPop(candidate); ++i) {
    if (!muted && candidate.generation == generation &&
        (!has_last || candidate.sequence > last_sequence)) {
      for (float sample : candidate.samples) {
        if (!std::isfinite(sample)) return FrameStatus::invalid_audio;
      }
      output = candidate;
      return FrameStatus::ready;
    }
  }
  return FrameStatus::no_frame;
}
}  // namespace boohta::deepfilter
#endif
