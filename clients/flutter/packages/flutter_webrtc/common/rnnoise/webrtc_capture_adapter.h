#ifndef BOOHTA_WEBRTC_CAPTURE_ADAPTER_H_
#define BOOHTA_WEBRTC_CAPTURE_ADAPTER_H_
#include "rtc_audio_processing.h"
#include "rnnoise_capture_processor.h"
#ifdef BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE
#include "experimental_deepfilter.h"
#endif
namespace boohta {
class WebrtcCaptureAdapter : public libwebrtc::RTCAudioProcessing::CustomProcessing {
#ifdef BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE
 private:
  // Processor is destroyed first; the factory stops capture before adapter teardown.
  std::unique_ptr<flutter_webrtc_plugin::ExperimentalDeepFilter> owner_;
#endif
 public:
#ifdef BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE
  explicit WebrtcCaptureAdapter(deepfilter::CaptureHook* hook = nullptr)
      : owner_(hook ? nullptr : flutter_webrtc_plugin::OpenExperimentalDeepFilter()),
        processor(std::malloc, hook ? hook : owner_ ? owner_->hook() : nullptr) {}
#else
  explicit WebrtcCaptureAdapter(deepfilter::CaptureHook* hook = nullptr) : processor(std::malloc, hook) {}
#endif
  void Initialize(int rate, int channels) override { processor.Initialize(rate, channels); }
  void Process(int bands, int frames, int capacity, float* pcm) override {
    processor.Process(pcm, frames, capacity);
  }
  void Reset(int rate) override { processor.Initialize(rate, processor.channels()); }
  void Release() override { processor.Reset(); }
  RnnoiseCaptureProcessor processor;
};
}
#endif
