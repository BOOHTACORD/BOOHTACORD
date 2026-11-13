#ifndef BOOHTA_DEEPFILTER_FRAME_EXCHANGE_H_
#define BOOHTA_DEEPFILTER_FRAME_EXCHANGE_H_

#include "../frame_queue/output.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>

namespace boohta::deepfilter {
enum class ExchangeStatus { ready, buffering, no_frame, invalid_audio, overload };

// Capture and Worker are each called by exactly one thread. The owner must
// advance generation on mute, unmute and failure, synchronize publication
// with mute intent, and reset the worker model on a generation change.
// Input and output each reference 480 floats of normalized mono PCM in [-1,
// 1], and may overlap. Failure and underflow return silence; fallback policy
// belongs to the owner. Startup buffering is reported separately from underrun;
// its delay and suitability must be measured before integration. Frames more
// than Capacity capture intervals old, or from the future, fail closed.
template <std::size_t Capacity>
class FrameExchange {
 public:
  explicit FrameExchange(std::size_t startup_frames = 0) noexcept
      : startup_frames_(std::min(startup_frames, Capacity - 1)), warmup_remaining_(startup_frames_) {}
  ExchangeStatus Capture(const float* input, std::uint64_t generation,
                         bool muted, float* output, std::uint64_t* emitted_sequence = nullptr) noexcept {
    if (emitted_sequence) *emitted_sequence = std::numeric_limits<std::uint64_t>::max();
    if (!output) return ExchangeStatus::invalid_audio;
    const auto silence = [output](ExchangeStatus status) noexcept {
      std::fill_n(output, 480, 0.0f); return status;
    };
    AudioFrame frame{};
    if (generation != last_generation_) {
      last_generation_ = generation; has_last_ = false; warmup_remaining_ = startup_frames_;
      TakeCurrentFrame(output_, generation, true, false, 0, frame);
    }
    if (muted) {
      TakeCurrentFrame(output_, generation, true, false, 0, frame);
      return silence(ExchangeStatus::no_frame);
    }
    if (!input) return silence(ExchangeStatus::invalid_audio);
    for (std::size_t i = 0; i < frame.samples.size(); ++i) {
      if (!std::isfinite(input[i]) || std::fabs(input[i]) > 1.0f) return silence(ExchangeStatus::invalid_audio);
      frame.samples[i] = input[i];
    }
    std::fill_n(output, 480, 0.0f);
    if (sequence_ == std::numeric_limits<std::uint64_t>::max()) return ExchangeStatus::overload;
    frame.generation = generation; frame.sequence = sequence_++;
    const auto current_sequence = frame.sequence;
    if (!input_.TryPush(frame)) return ExchangeStatus::overload;
    if (warmup_remaining_ > 0) { --warmup_remaining_; return ExchangeStatus::buffering; }
    const auto result = TakeCurrentFrame(output_, generation, false, has_last_, last_sequence_, frame);
    if (result == FrameStatus::invalid_audio) return ExchangeStatus::invalid_audio;
    if (result != FrameStatus::ready) return ExchangeStatus::no_frame;
    if (frame.sequence > current_sequence || current_sequence - frame.sequence > Capacity) return ExchangeStatus::overload;
    for (float sample : frame.samples) if (std::fabs(sample) > 1.0f) return ExchangeStatus::invalid_audio;
    has_last_ = true; last_sequence_ = frame.sequence;
    if (emitted_sequence) *emitted_sequence = frame.sequence;
    std::copy(frame.samples.begin(), frame.samples.end(), output);
    return ExchangeStatus::ready;
  }

  bool WorkerPop(std::uint64_t generation, AudioFrame& frame) noexcept {
    for (std::size_t i = 0; i < Capacity && input_.TryPop(frame); ++i)
      if (frame.generation == generation) return true;
    frame = AudioFrame{};
    return false;
  }
  bool WorkerPush(const AudioFrame& frame) noexcept { return output_.TryPush(frame); }

 private:
  FrameQueue<Capacity> input_, output_;
  const std::size_t startup_frames_;
  std::size_t warmup_remaining_;
  std::uint64_t sequence_ = 0, last_sequence_ = 0, last_generation_ = 0;
  bool has_last_ = false;
};
}  // namespace boohta::deepfilter
#endif
