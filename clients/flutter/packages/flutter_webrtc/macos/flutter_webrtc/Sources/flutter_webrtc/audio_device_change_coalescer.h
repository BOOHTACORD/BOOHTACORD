#ifndef FLUTTER_WEBRTC_AUDIO_DEVICE_CHANGE_COALESCER_H_
#define FLUTTER_WEBRTC_AUDIO_DEVICE_CHANGE_COALESCER_H_

#include <cstdint>

namespace flutter_webrtc_plugin {

class AudioDeviceChangeCoalescer {
 public:
  using Token = std::uint64_t;

  Token schedule() { return ++generation_; }
  bool shouldEmit(Token token) const { return token == generation_; }
  void cancel() { ++generation_; }

 private:
  Token generation_ = 0;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_AUDIO_DEVICE_CHANGE_COALESCER_H_
