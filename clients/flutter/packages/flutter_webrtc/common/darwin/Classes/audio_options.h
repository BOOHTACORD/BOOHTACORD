/*
 * Copyright (c) 2018 The WebRTC project authors. All Rights Reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file in the root of the source tree. An additional
 * intellectual property rights grant can be found in the file PATENTS. All
 * contributing project authors may be found in the AUTHORS file in the root
 * of the source tree.
 */

#ifndef FLUTTER_WEBRTC_AUDIO_OPTIONS_H_
#define FLUTTER_WEBRTC_AUDIO_OPTIONS_H_

#include <optional>
#include <string>

namespace webrtc {

enum class AudioProcessingMode {
  kAutomatic = 0,
  kPlatform = 1,
  kSoftware = 2,
};

// ABI-compatible subset of api/audio_options.h from the pinned m150 WebRTC
// SDK. The fields and order match the SDK struct; inline value operations let
// Android's capture bridge build without linking a second copy of libwebrtc.
struct AudioOptions {
  AudioOptions() = default;
  ~AudioOptions() = default;
  void SetAll(const AudioOptions& change);

  bool operator==(const AudioOptions& other) const;
  bool operator!=(const AudioOptions& other) const { return !(*this == other); }
  std::string ToString() const;

  std::optional<bool> echo_cancellation;
  std::optional<AudioProcessingMode> echo_cancellation_mode;
#if defined(WEBRTC_IOS)
  [[deprecated]] std::optional<bool> ios_force_software_aec_HACK;
#endif
  std::optional<bool> auto_gain_control;
  std::optional<AudioProcessingMode> auto_gain_control_mode;
  std::optional<bool> noise_suppression;
  std::optional<AudioProcessingMode> noise_suppression_mode;
  std::optional<bool> highpass_filter;
  std::optional<AudioProcessingMode> highpass_filter_mode;
  std::optional<bool> stereo_swapping;
  std::optional<int> audio_jitter_buffer_max_packets;
  std::optional<bool> audio_jitter_buffer_fast_accelerate;
  std::optional<int> audio_jitter_buffer_min_delay_ms;
  std::optional<bool> audio_network_adaptor;
  std::optional<std::string> audio_network_adaptor_config;
  std::optional<bool> init_recording_on_send;
};

}  // namespace webrtc

#endif  // FLUTTER_WEBRTC_AUDIO_OPTIONS_H_
