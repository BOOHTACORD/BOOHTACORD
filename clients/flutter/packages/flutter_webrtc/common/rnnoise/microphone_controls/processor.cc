#include "processor.h"
#include <algorithm>
#include <cmath>
namespace boohta {
void MicrophoneControls::Initialize(int rate, int channels) {
  rate_.store(rate); channels_.store(channels);
  supported_.store(rate >= 8000 && rate <= 96000 && channels == 1); Reset();
}
void MicrophoneControls::Configure(float threshold, float percent, bool vad, bool agc, bool enabled) {
  threshold_.store(std::isfinite(threshold) ? std::clamp(threshold, -70.f, -20.f) : -50.f);
  percent_.store(std::isfinite(percent) ? std::clamp(percent, 0.f, 200.f) : 100.f);
  agc_.store(agc);
  const bool mode_changed = vad_.exchange(vad) != vad;
  const bool enable_changed = enabled_.exchange(enabled) != enabled;
  if (mode_changed || enable_changed) Reset();
}
void MicrophoneControls::Reset() {
  generation_.fetch_add(1); applied_.store(false);
  level_.store(-90); open_.store(false); clipped_.store(false);
}
void MicrophoneControls::Process(float* pcm, int frames, int capacity) {
  if (!enabled_.load()) return;
  const int rate = rate_.load();
  const bool valid = pcm && rate >= 8000 && rate <= 96000 &&
      channels_.load() == 1 && frames == rate / 100 && capacity >= frames;
  supported_.store(valid);
  if (!valid) {
    applied_.store(false);
    if (pcm && frames > 0 && capacity >= frames) std::fill_n(pcm, frames, 0.f);
    return;
  }
  const auto generation = generation_.load();
  if (generation != current_generation_) {
    delay_.fill(0); index_ = 0; hold_ = 0; clipping_hold_ = 0; gate_ = false; gain_ = 1;
#if defined(_WIN32)
    gate_gain_ = 0;
#endif
    current_generation_ = generation;
  }
  double energy = 0;
  for (int i = 0; i < frames; ++i) {
    if (!std::isfinite(pcm[i])) pcm[i] = 0;
    const double normalized = pcm[i] / 32768.;
    energy += normalized * normalized;
  }
  const float db = std::max(-90., 10 * std::log10(std::max(1e-9, energy / frames)));
  level_.store(db);
  if (db >= threshold_.load() - (gate_ ? 6 : 0)) { gate_ = true; hold_ = rate / 5; }
  else { hold_ = std::max(0, hold_ - frames); if (!hold_) gate_ = false; }
  const bool vad = vad_.load();
  const float target = agc_.load() ? 1 : percent_.load() / 100;
  if (target == 0) gain_ = 0;
  const float step = 100.f / rate;
#if defined(_WIN32)
  const float gate_step = (gate_ ? 200.f : -20.f) / rate;
#endif
  const int delay_length = rate / 50;
  bool clipped = false;
  for (int i = 0; i < frames; ++i) {
    const float sample = pcm[i], delayed = delay_[index_];
    delay_[index_] = sample; index_ = (index_ + 1) % delay_length;
    gain_ += std::clamp(target - gain_, -step, step);
#if defined(_WIN32)
    if (vad) gate_gain_ = std::clamp(gate_gain_ + gate_step, 0.f, 1.f);
    const float value = (vad ? delayed * gate_gain_ : sample) * gain_;
#else
    const float value = (!vad || gate_) ? (vad ? delayed : sample) * gain_ : 0;
#endif
    clipped |= value > 32767 || value < -32768;
    pcm[i] = std::clamp(value, -32768.f, 32767.f);
  }
  // Never mark stale control/capture generations as applied.
  applied_.store(generation == generation_.load());
  clipping_hold_ = clipped ? rate / 4 : std::max(0, clipping_hold_ - frames);
  clipped_.store(clipping_hold_ > 0); open_.store(!vad || gate_);
}
}
