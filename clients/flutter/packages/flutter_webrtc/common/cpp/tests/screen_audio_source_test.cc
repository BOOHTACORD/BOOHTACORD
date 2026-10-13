#include "ScreenAudioSource.h"

#include <array>
#include <algorithm>
#include <cassert>
#include <vector>

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

class FramedSink final : public webrtc::AudioTrackSinkInterface {
 public:
  void OnData(const void* data, int bits, int rate, size_t channels,
              size_t frames) override {
    assert(bits == 16);
    assert(frames == static_cast<size_t>(rate / 100));
    const auto* pcm = static_cast<const int16_t*>(data);
    received.insert(received.end(), pcm, pcm + frames * channels);
    ++blocks;
  }
  std::vector<int16_t> received;
  size_t blocks = 0;
};

void CheckFraming(size_t channels) {
  auto source = rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource>(
      new flutter_webrtc_plugin::ScreenAudioSource());
#if defined(BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING)
  assert(source->source_type() == webrtc::AudioSourceInterface::SourceType::kCustom);
#endif
  FramedSink sink;
  source->AddSink(&sink);
  std::vector<int16_t> expected;
  size_t total_frames = 0;
  for (size_t frames : {128, 256, 480, 512, 960, 1024, 2048}) {
    std::vector<int16_t> pcm(frames * channels);
    for (size_t i = 0; i < pcm.size(); ++i) {
      pcm[i] = static_cast<int16_t>((expected.size() + i) % 16000);
    }
    expected.insert(expected.end(), pcm.begin(), pcm.end());
    source->CaptureFrame(pcm.data(), 16, 48000, channels, frames);
    total_frames += frames;
    assert(sink.blocks == total_frames / 480);
    assert(sink.received.size() == total_frames / 480 * 480 * channels);
    assert(std::equal(sink.received.begin(), sink.received.end(), expected.begin()));
  }
  // Completing the carried residual retains original order, with no silence.
  const size_t tail = 480 - total_frames % 480;
  std::vector<int16_t> pcm(tail * channels, 1234);
  expected.insert(expected.end(), pcm.begin(), pcm.end());
  source->CaptureFrame(pcm.data(), 16, 48000, channels, tail);
  assert(sink.received == expected);
  source->Stop();
  source->CaptureFrame(pcm.data(), 16, 48000, channels, tail);
  assert(sink.received == expected);
}

void CheckFormatAndSinkReset() {
  auto source = rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource>(
      new flutter_webrtc_plugin::ScreenAudioSource());
  FramedSink sink;
  source->AddSink(&sink);
  std::array<int16_t, 960> pcm;
  pcm.fill(300);
  source->CaptureFrame(pcm.data(), 16, 48000, 2, 128);
  pcm.fill(600);
  source->CaptureFrame(pcm.data(), 16, 16000, 1, 160);
  assert(sink.received == std::vector<int16_t>(160, 600));
  source->CaptureFrame(pcm.data(), 16, 48000, 2, 128);
  source->RemoveSink(&sink);
  source->AddSink(&sink);
  pcm.fill(900);
  source->CaptureFrame(pcm.data(), 16, 48000, 2, 480);
  assert(sink.received.size() == 1120);
  assert(std::all_of(sink.received.begin() + 160, sink.received.end(),
                     [](int16_t sample) { return sample == 900; }));
}

}  // namespace

int main() {
  CheckFraming(1);
  CheckFraming(2);
  CheckFormatAndSinkReset();
  auto source = rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource>(
      new flutter_webrtc_plugin::ScreenAudioSource());
  assert(source->source_type() ==
         webrtc::AudioSourceInterface::SourceType::kCustom);
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
