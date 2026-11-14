#include "rnnoise_capture_processor.h"
#include "deepfilter/capture_hook/interface.h"
#include <cmath>
#include "preflight/warmup.h"
namespace boohta {
RnnoiseCaptureProcessor::RnnoiseCaptureProcessor(StateAllocator allocate, deepfilter::CaptureHook* hook)
    : state_(static_cast<DenoiseState*>(allocate(rnnoise_get_size()))), hook_(hook) {
  // v0.1 rnnoise_create does not check malloc. Keep pinned source untouched and
  // initialize only successful allocations so unavailable is an honest fallback.
  state_ready_.store(state_ && rnnoise_init(state_) == 0);
  if (!state_ready_.load()) failure_.store(Failure::kUnavailable);
  // Stock v0.1 lazily allocates its global FFT tables on the first process call.
  // Warm on the control thread exactly once before any realtime callback.
  if (state_ready_.load()) {
    WarmRnnoiseFft(state_);
    warmed_ = true; state_ready_.store(rnnoise_init(state_) == 0);
  }
}
RnnoiseCaptureProcessor::~RnnoiseCaptureProcessor() { rnnoise_destroy(state_); }
void RnnoiseCaptureProcessor::SetEngine(Engine engine) {
  requested_.store(engine);
  Reset();
}
void RnnoiseCaptureProcessor::Reset() {
  controls.Reset();
  generation_.fetch_add(1);
  if (hook_) hook_->Reset(requested_.load() == Engine::kDeepFilter);
  failure_.store(supported() ? Failure::kAwaitingAudio : Failure::kUnavailable);
}
void RnnoiseCaptureProcessor::Initialize(int rate, int channels) {
  rate_.store(rate); channels_.store(channels); controls.Initialize(rate, channels); Reset();
}
bool RnnoiseCaptureProcessor::Process(float* pcm, int frames, int capacity) {
  const bool processed = ProcessNoise(pcm, frames, capacity);
  controls.Process(pcm, frames, capacity);
  return processed;
}
bool RnnoiseCaptureProcessor::ProcessNoise(float* pcm, int frames, int capacity) {
  const auto generation = generation_.load();
  if (generation != applied_generation_) {
    state_ready_.store(warmed_ && state_ && rnnoise_init(state_) == 0);
    resampler_.Reset();
    applied_generation_ = generation;
  }
  if (requested_.load() == Engine::kDeepFilter) return ProcessDeepFilter(pcm, frames, capacity, generation);
  if (requested_.load() != Engine::kRnnoise) return false;
#ifdef BOOHTA_RNNOISE_V02_RESEARCH
  if (rate_.load() == 16000 && frames == 160)
    return ProcessResearchV02At16k(pcm, frames, capacity, generation);
#endif
  Failure error = Failure::kNone;
  if (!state_ready_.load()) error = Failure::kUnavailable;
  else if (!pcm || rate_.load() != 48000 || channels_.load() != 1 ||
           frames != 480 || capacity < frames) error = Failure::kFormat;
  else for (int i = 0; i < frames; ++i) {
    if (!std::isfinite(pcm[i]) || std::fabs(pcm[i]) > 32768.f) {
      error = Failure::kNonFinite; break;
    }
  }
  if (error != Failure::kNone) {
    failure_.store(error); fallback_.fetch_add(1);
    state_ready_.store(warmed_ && state_ && rnnoise_init(state_) == 0);
    return false;
  }
  // RNNoise v0.1 consumes fullband float PCM on the same S16 amplitude scale
  // used by WebRTC AudioBuffer. There is no normalized-float conversion here.
  rnnoise_process_frame(state_, pcm, pcm);
  if (generation == generation_.load() && requested_.load() == Engine::kRnnoise)
    failure_.store(Failure::kNone);
  processed_.fetch_add(1);
  return true;
}
RnnoiseCaptureProcessor::Engine RnnoiseCaptureProcessor::EffectiveEngine() const {
  auto requested = requested_.load();
  return (requested == Engine::kRnnoise || requested == Engine::kDeepFilter) && failure_.load() != Failure::kNone
      ? Engine::kUnknown : requested;
}
const char* RnnoiseCaptureProcessor::failure_reason() const {
  if (requested_.load() != Engine::kRnnoise && requested_.load() != Engine::kDeepFilter) return "";
  if (requested_.load() == Engine::kDeepFilter && hook_ && failure_.load() == Failure::kAwaitingAudio) {
    const auto readiness = hook_->Readiness();
    if (readiness == deepfilter::HookReadiness::preparing) return "awaiting-model";
    if (readiness == deepfilter::HookReadiness::failed) return "processor-failed";
  }
  switch (failure_.load()) {
    case Failure::kNone: return "";
    case Failure::kAwaitingAudio: return "awaiting-audio";
    case Failure::kFormat: return "unsupported-audio-format";
    case Failure::kNonFinite: return "invalid-audio-samples";
    case Failure::kUnavailable: return "processor-unavailable";
    case Failure::kProcessor: return "processor-failed";
    case Failure::kUnderrun: return "processor-underrun";
  }
  return "processor-unavailable";
}
}
