#ifndef BOOHTA_MICROPHONE_CONTROLS_H_
#define BOOHTA_MICROPHONE_CONTROLS_H_
#include <array>
#include <atomic>
#include <cstdint>
namespace boohta {
// Control-thread atomics; fixed audio-thread storage. Never retain borrowed PCM.
class MicrophoneControls {
 public:
  void Initialize(int rate, int channels);
  void Configure(float threshold, float percent, bool vad, bool agc, bool enabled);
  void Reset();
  void Process(float* pcm, int frames, int capacity);
  bool supported() const { return supported_.load(); }
  bool applied() const { return applied_.load(); }
  float level_db() const { return level_.load(); }
  bool clipping() const { return clipped_.load(); }
  bool gate_open() const { return open_.load(); }
 private:
  std::atomic<float> threshold_{-50}, percent_{100}, level_{-90};
  std::atomic<bool> vad_{true}, agc_{true}, enabled_{false};
  std::atomic<bool> supported_{false}, applied_{false}, clipped_{false}, open_{false};
  std::atomic<int> rate_{0}, channels_{0};
  std::atomic<uint64_t> generation_{1};
  uint64_t current_generation_ = 0;
  std::array<float, 1920> delay_{};
  int index_ = 0, hold_ = 0, clipping_hold_ = 0;
  bool gate_ = false;
  float gain_ = 1;
#if defined(_WIN32)
  float gate_gain_ = 0;
#endif
};
}
#endif
