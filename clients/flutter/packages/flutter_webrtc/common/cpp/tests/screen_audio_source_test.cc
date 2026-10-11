#include "ScreenAudioSource.h"

#include <array>
#include <cassert>

namespace {

class RecordingSink final : public webrtc::AudioTrackSinkInterface {
 public:
  void OnData(const void* data,
              int bitsPerSample,
              int sampleRate,
              size_t channels,
              size_t frames) override {
    called++;
    lastBits = bitsPerSample;
    lastSampleRate = sampleRate;
    lastChannels = channels;
    lastFrames = frames;
    lastSample = static_cast<const int16_t*>(data)[0];
  }

  int called = 0;
  int lastBits = 0;
  int lastSampleRate = 0;
  size_t lastChannels = 0;
  size_t lastFrames = 0;
  int16_t lastSample = 0;
};

class RemovingSink final : public webrtc::AudioTrackSinkInterface {
 public:
  explicit RemovingSink(flutter_webrtc_plugin::ScreenAudioSource* source) : source_(source) {}

  void OnData(const void*, int, int, size_t, size_t) override {
    ++called;
    source_->RemoveSink(this);
  }

  int called = 0;

 private:
  flutter_webrtc_plugin::ScreenAudioSource* source_;
};

}  // namespace

int main() {
  auto source = rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource>(
      new flutter_webrtc_plugin::ScreenAudioSource());
  RecordingSink sink;
  source->AddSink(&sink);
  std::array<int16_t, 960> pcm;
  pcm.fill(1200);

  source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  assert(sink.called == 1);
  assert(sink.lastBits == 16);
  assert(sink.lastSampleRate == 48000);
  assert(sink.lastChannels == 2);
  assert(sink.lastFrames == 480);
  assert(sink.lastSample == 1200);

  source->SetVolume(2.0);
  source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  assert(sink.called == 2);
  assert(sink.lastSample == 2400);

  source->Stop();
  source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  assert(source->state() == webrtc::MediaSourceInterface::kEnded);
  assert(sink.called == 2);
  source->RemoveSink(&sink);

  auto callback_source = rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource>(
      new flutter_webrtc_plugin::ScreenAudioSource());
  RemovingSink removing_sink(callback_source.get());
  callback_source->AddSink(&removing_sink);
  callback_source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  callback_source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  assert(removing_sink.called == 1);
  return 0;
}
