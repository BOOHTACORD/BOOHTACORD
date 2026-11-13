#ifndef TEST_RTC_AUDIO_PROCESSING_H_
#define TEST_RTC_AUDIO_PROCESSING_H_
namespace libwebrtc {
class RTCAudioProcessing {
 public:
  class CustomProcessing {
   public:
    virtual ~CustomProcessing() = default;
    virtual void Initialize(int, int) = 0;
    virtual void Process(int, int, int, float*) = 0;
    virtual void Reset(int) = 0;
    virtual void Release() = 0;
  };
};
}
#endif
