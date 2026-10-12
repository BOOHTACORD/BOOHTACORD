/*
 * Copyright (c) 2026 The BOOHTACORD contributors.
 *
 * This file is part of the flutter_webrtc native screen-audio bridge.
 * Licensed under the BSD 3-Clause license, matching the vendored WebRTC API.
 */

#include "ScreenAudioSource.h"

#include <algorithm>
#include <cmath>

namespace flutter_webrtc_plugin {

ScreenAudioSource::ScreenAudioSource() {
  // System audio is already mixed. Voice-specific processing would distort it.
  options_.echo_cancellation = false;
  options_.auto_gain_control = false;
  options_.noise_suppression = false;
  options_.highpass_filter = false;
  options_.init_recording_on_send = false;
}

void ScreenAudioSource::AddRef() const {
  references_.fetch_add(1, std::memory_order_relaxed);
}

webrtc::RefCountReleaseStatus ScreenAudioSource::Release() const {
  const int remaining = references_.fetch_sub(1, std::memory_order_acq_rel) - 1;
  if (remaining == 0) {
    delete this;
    return webrtc::RefCountReleaseStatus::kDroppedLastRef;
  }
  return webrtc::RefCountReleaseStatus::kOtherRefsRemained;
}

ScreenAudioSource::SourceState ScreenAudioSource::state() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return state_;
}

void ScreenAudioSource::RegisterObserver(webrtc::ObserverInterface* observer) {
  if (observer == nullptr) return;
  std::lock_guard<std::mutex> lock(mutex_);
  if (std::find(observers_.begin(), observers_.end(), observer) == observers_.end()) {
    observers_.push_back(observer);
  }
}

void ScreenAudioSource::UnregisterObserver(webrtc::ObserverInterface* observer) {
  std::lock_guard<std::mutex> lock(mutex_);
  observers_.erase(std::remove(observers_.begin(), observers_.end(), observer), observers_.end());
}

void ScreenAudioSource::SetVolume(double volume) {
  std::vector<AudioObserver*> observers;
  double clamped = std::clamp(volume, 0.0, 10.0);
  {
    std::lock_guard<std::mutex> lock(mutex_);
    volume_ = clamped;
    observers = audioObservers_;
  }
  for (auto* observer : observers) {
    if (observer != nullptr) observer->OnSetVolume(clamped);
  }
}

double ScreenAudioSource::GetVolume() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return volume_;
}

void ScreenAudioSource::RegisterAudioObserver(AudioObserver* observer) {
  if (observer == nullptr) return;
  std::lock_guard<std::mutex> lock(mutex_);
  if (std::find(audioObservers_.begin(), audioObservers_.end(), observer) == audioObservers_.end()) {
    audioObservers_.push_back(observer);
  }
}

void ScreenAudioSource::UnregisterAudioObserver(AudioObserver* observer) {
  std::lock_guard<std::mutex> lock(mutex_);
  audioObservers_.erase(
      std::remove(audioObservers_.begin(), audioObservers_.end(), observer), audioObservers_.end());
}

void ScreenAudioSource::AddSink(webrtc::AudioTrackSinkInterface* sink) {
  if (sink == nullptr) return;
  std::lock_guard<std::mutex> lock(mutex_);
  if (std::find(sinks_.begin(), sinks_.end(), sink) == sinks_.end()) sinks_.push_back(sink);
}

void ScreenAudioSource::RemoveSink(webrtc::AudioTrackSinkInterface* sink) {
  std::lock_guard<std::recursive_mutex> capture_lock(capture_mutex_);
  std::lock_guard<std::mutex> lock(mutex_);
  sinks_.erase(std::remove(sinks_.begin(), sinks_.end(), sink), sinks_.end());
}

const webrtc::AudioOptions ScreenAudioSource::options() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return options_;
}

void ScreenAudioSource::SetOptions(const webrtc::AudioOptions& options) {
  std::lock_guard<std::mutex> lock(mutex_);
  options_ = options;
}

void ScreenAudioSource::CaptureFrame(const void* audioData,
                                     int bitsPerSample,
                                     int sampleRate,
                                     size_t channels,
                                     size_t frames) {
  if (audioData == nullptr || bitsPerSample != 16 || sampleRate <= 0 || channels == 0 || frames == 0) {
    return;
  }
  if (sampleRate < 8000 || sampleRate > 96000 || channels > 2 ||
      frames > 96000 || frames > SIZE_MAX / channels) {
    return;
  }

  std::lock_guard<std::recursive_mutex> capture_lock(capture_mutex_);
  double volume;
  std::vector<webrtc::AudioTrackSinkInterface*> sinks;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (state_ != kLive) return;
    volume = volume_;
    sinks = sinks_;
  }

  const int16_t* input = static_cast<const int16_t*>(audioData);
  std::vector<int16_t> adjusted;
  const int16_t* data = input;
  if (std::abs(volume - 1.0) > 0.0001) {
    adjusted.resize(frames * channels);
    for (size_t i = 0; i < adjusted.size(); ++i) {
      const double sample = static_cast<double>(input[i]) * volume;
      adjusted[i] = static_cast<int16_t>(std::clamp(sample, -32768.0, 32767.0));
    }
    data = adjusted.data();
  }

  for (auto* sink : sinks) {
    if (sink == nullptr || state() != kLive) break;
    sink->OnData(data, bitsPerSample, sampleRate, channels, frames);
  }
}

void ScreenAudioSource::Stop() {
  std::lock_guard<std::recursive_mutex> capture_lock(capture_mutex_);
  std::vector<webrtc::ObserverInterface*> observers;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (state_ == kEnded) return;
    state_ = kEnded;
    sinks_.clear();
    observers = observers_;
  }
  for (auto* observer : observers) {
    if (observer != nullptr) observer->OnChanged();
  }
}

}  // namespace flutter_webrtc_plugin
