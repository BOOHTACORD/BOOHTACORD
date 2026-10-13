/*
 * Copyright (c) 2026 The BOOHTACORD contributors.
 *
 * This file is part of the flutter_webrtc native screen-audio bridge.
 * Licensed under the BSD 3-Clause license, matching the vendored WebRTC API.
 */

#ifndef FLUTTER_WEBRTC_SCREEN_AUDIO_SOURCE_H_
#define FLUTTER_WEBRTC_SCREEN_AUDIO_SOURCE_H_

#include <atomic>
#include <array>
#include <cstdint>
#include <mutex>
#include <vector>

#include "audio_options.h"
#include "media_stream_interface.h"

namespace flutter_webrtc_plugin {

// A push source used only for system/app audio. OS capture callbacks feed
// signed 16-bit PCM into this object; WebRTC's AudioTrackSinkInterface then
// carries it through the normal audio sender and LiveKit publication path.
class ScreenAudioSource final : public webrtc::AudioSourceInterface {
 public:
  ScreenAudioSource();
  ~ScreenAudioSource() override = default;

  void AddRef() const override;
  webrtc::RefCountReleaseStatus Release() const override;
  SourceState state() const override;
  bool remote() const override { return false; }

  void RegisterObserver(webrtc::ObserverInterface* observer) override;
  void UnregisterObserver(webrtc::ObserverInterface* observer) override;
  void SetVolume(double volume) override;
  double GetVolume() const override;
  void RegisterAudioObserver(AudioObserver* observer) override;
  void UnregisterAudioObserver(AudioObserver* observer) override;
  void AddSink(webrtc::AudioTrackSinkInterface* sink) override;
  void RemoveSink(webrtc::AudioTrackSinkInterface* sink) override;
  const webrtc::AudioOptions options() const override;
  void SetOptions(const webrtc::AudioOptions& options) override;
#if defined(BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING)
  SourceType source_type() const override { return SourceType::kCustom; }
#endif

  // Input contract: interleaved signed 16-bit PCM. The capture APIs may supply
  // mono or stereo frames at their native sample rate and block size.
  void CaptureFrame(const void* audioData,
                    int bitsPerSample,
                    int sampleRate,
                    size_t channels,
                    size_t frames);
  void Stop();

 private:
  mutable std::atomic<int> references_{0};
  mutable std::recursive_mutex capture_mutex_;
  mutable std::mutex mutex_;
  SourceState state_ = kLive;
  double volume_ = 1.0;
  webrtc::AudioOptions options_;
  std::vector<webrtc::ObserverInterface*> observers_;
  std::vector<AudioObserver*> audioObservers_;
  std::vector<webrtc::AudioTrackSinkInterface*> sinks_;
  // At most one 10 ms interleaved block. Guarded by capture_mutex_.
  std::array<int16_t, 1920> pending_pcm_{};
  size_t pending_samples_ = 0;
  int pending_sample_rate_ = 0;
  size_t pending_channels_ = 0;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_SCREEN_AUDIO_SOURCE_H_
