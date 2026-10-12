#import "ScreenAudioTrackCapturer.h"

#include <atomic>

#import "RTCAudioSource+Private.h"
#import "ScreenAudioPCMConverter.h"
#import "ScreenAudioSource.h"

@interface RTCAudioSource (FlutterScreenAudioSource)
- (instancetype)initWithFactory:(RTCPeerConnectionFactory *)factory
              nativeAudioSource:(rtc::scoped_refptr<webrtc::AudioSourceInterface>)nativeAudioSource;
@end

@implementation FlutterScreenAudioTrackCapturer {
  rtc::scoped_refptr<flutter_webrtc_plugin::ScreenAudioSource> _source;
  RTCAudioSource *_rtcSource;
  std::atomic_bool _stopped;
}

- (instancetype)initWithFactory:(RTCPeerConnectionFactory *)factory {
  self = [super init];
  if (self) {
    _stopped.store(false, std::memory_order_relaxed);
    _source = new flutter_webrtc_plugin::ScreenAudioSource();
    _rtcSource = [[RTCAudioSource alloc] initWithFactory:factory nativeAudioSource:_source];
    NSString *trackId = [[NSUUID UUID] UUIDString];
    _audioTrack = [factory audioTrackWithSource:_rtcSource trackId:trackId];
  }
  return self;
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  if (_stopped.load(std::memory_order_acquire)) return;
  int sampleRate = 0;
  size_t channels = 0;
  size_t frames = 0;
  NSData *data = FlutterScreenAudioPCMDataFromSampleBuffer(sampleBuffer, &sampleRate, &channels, &frames);
  [self appendPCMData:data sampleRate:sampleRate channels:channels frames:frames];
}

- (void)appendPCMData:(NSData *)data
           sampleRate:(int)sampleRate
             channels:(size_t)channels
                frames:(size_t)frames {
  if (_stopped.load(std::memory_order_acquire) || data == nil || sampleRate <= 0 || channels == 0 || frames == 0 ||
      data.length < frames * channels * sizeof(int16_t)) {
    return;
  }
  _source->CaptureFrame(data.bytes, 16, sampleRate, channels, frames);
}

- (void)stop {
  if (_stopped.exchange(true, std::memory_order_acq_rel)) return;
  if (_source.get() != nullptr) _source->Stop();
}

@end
