#ifndef BOOHTA_DEEPFILTER_CAPTURE_BRIDGE_H_
#define BOOHTA_DEEPFILTER_CAPTURE_BRIDGE_H_

#include "../frame_exchange/exchange.h"
#include <cmath>
#include <cstdint>
#include <limits>

namespace boohta::deepfilter {
// WebRTC supplies mono float PCM on an S16 scale. The worker uses normalized
// floats. Only successful/buffering calls replace PCM; errors leave it intact
// so the owner can stop this generation and choose its fallback explicitly.
// One capture thread and one worker thread; owner controls lifetime and mute.
template <std::size_t Capacity>
class CaptureBridge {
 public:
  explicit CaptureBridge(std::size_t startup_frames = 0) noexcept : exchange_(startup_frames) {}

  ExchangeStatus Capture(float* pcm, int frames, int capacity, int rate, int channels,
                         std::uint64_t generation, bool muted,
                         std::uint64_t* emitted_sequence = nullptr) noexcept {
    if (emitted_sequence) *emitted_sequence = std::numeric_limits<std::uint64_t>::max();
    if (!pcm || frames != 480 || capacity < frames || rate != 48000 || channels != 1)
      return ExchangeStatus::invalid_audio;
    float input[480], output[480];
    if (muted) {
      const auto result = exchange_.Capture(nullptr, generation, true, output);
      for (int i = 0; i < 480; ++i) pcm[i] = 0.f;
      return result;
    }
    for (int i = 0; i < 480; ++i) {
      if (!std::isfinite(pcm[i]) || std::fabs(pcm[i]) > 32768.f)
        return ExchangeStatus::invalid_audio;
      input[i] = pcm[i] / 32768.f;
    }
    const auto result = exchange_.Capture(input, generation, false, output, emitted_sequence);
    if (result == ExchangeStatus::ready || result == ExchangeStatus::buffering ||
        result == ExchangeStatus::no_frame) {
      for (int i = 0; i < 480; ++i) pcm[i] = output[i] * 32768.f;
    }
    return result;
  }

  bool WorkerPop(std::uint64_t generation, AudioFrame& frame) noexcept {
    return exchange_.WorkerPop(generation, frame);
  }
  bool WorkerPush(const AudioFrame& frame) noexcept { return exchange_.WorkerPush(frame); }
  // Only the worker thread may use the returned exchange's worker methods.
  FrameExchange<Capacity>& WorkerExchange() noexcept { return exchange_; }

 private:
  FrameExchange<Capacity> exchange_;
};
}  // namespace boohta::deepfilter
#endif
