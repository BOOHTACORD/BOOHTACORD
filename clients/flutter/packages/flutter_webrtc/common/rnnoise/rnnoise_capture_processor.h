#ifndef BOOHTA_RNNOISE_CAPTURE_PROCESSOR_H_
#define BOOHTA_RNNOISE_CAPTURE_PROCESSOR_H_
#include <atomic>
#include "microphone_controls/processor.h"
#include "deepfilter/resample_16k/resampler.h"
#include <cstdint>
#include <cstdlib>
extern "C" {
#include "upstream/include/rnnoise.h"
}
namespace boohta {
namespace deepfilter { class CaptureHook; }
// Audio-owned state. Control threads touch only atomics. The caller borrows the
// PCM until Process returns and must stop capture before destroying this object.
class RnnoiseCaptureProcessor {
 public:
  enum class Engine { kOff, kBrowser, kRnnoise, kDeepFilter, kUnknown };
  enum class Failure { kAwaitingAudio, kNone, kFormat, kNonFinite, kUnavailable, kProcessor, kUnderrun };
  using StateAllocator = void* (*)(size_t);
  explicit RnnoiseCaptureProcessor(StateAllocator allocate = std::malloc, deepfilter::CaptureHook* hook = nullptr);
  ~RnnoiseCaptureProcessor();
  RnnoiseCaptureProcessor(const RnnoiseCaptureProcessor&) = delete;
  RnnoiseCaptureProcessor& operator=(const RnnoiseCaptureProcessor&) = delete;
  void SetEngine(Engine engine);
  void Reset();
  void Initialize(int rate, int channels);
  bool Process(float* pcm, int frames, int capacity);
  Engine requested_engine() const { return requested_.load(); }
  Engine EffectiveEngine() const;
  const char* failure_reason() const;
  uint64_t processed_frames() const { return processed_.load(); }
  uint64_t fallback_frames() const { return fallback_.load(); }
  int sample_rate() const { return rate_.load(); }
  int channels() const { return channels_.load(); }
  bool supported() const;
  MicrophoneControls controls;
 private:
  bool ProcessNoise(float* pcm, int frames, int capacity);
#ifdef BOOHTA_RNNOISE_V02_RESEARCH
  bool ProcessResearchV02At16k(float* pcm, int frames, int capacity, uint64_t generation);
#endif
  bool ProcessDeepFilter(float* pcm, int frames, int capacity, uint64_t generation);
  deepfilter::Resampler16k resampler_;
  DenoiseState* state_;
  deepfilter::CaptureHook* const hook_;
  std::atomic<Engine> requested_{Engine::kBrowser};
  std::atomic<Failure> failure_{Failure::kAwaitingAudio};
  std::atomic<uint64_t> generation_{1}, processed_{0}, fallback_{0};
  std::atomic<int> rate_{0}, channels_{0};
  uint64_t applied_generation_ = 0;
};
const char* NoiseEngineName(RnnoiseCaptureProcessor::Engine engine);
bool ParseNoiseEngine(const char* value, RnnoiseCaptureProcessor::Engine* engine);
}
#endif
