#ifndef BOOHTA_WEBRTC_CAPTURE_ADAPTER_H_
#define BOOHTA_WEBRTC_CAPTURE_ADAPTER_H_
#include "rtc_audio_processing.h"
#include "rnnoise_capture_processor.h"
namespace boohta {
class WebrtcCaptureAdapter : public libwebrtc::RTCAudioProcessing::CustomProcessing {
 public:
  explicit WebrtcCaptureAdapter(deepfilter::CaptureHook* hook = nullptr) : processor(std::malloc, hook) {}
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
