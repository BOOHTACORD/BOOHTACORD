#import <WebRTC/WebRTC.h>

#import <CoreMedia/CoreMedia.h>

/// Owns a WebRTC audio track backed by PCM supplied by a screen-capture API.
/// The input buffer is copied and normalized before it enters WebRTC.
@interface FlutterScreenAudioTrackCapturer : NSObject

@property(nonatomic, strong, readonly) RTCAudioTrack *audioTrack;

- (instancetype)initWithFactory:(RTCPeerConnectionFactory *)factory;
- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (BOOL)appendPCMData:(NSData *)data
           sampleRate:(int)sampleRate
             channels:(size_t)channels
                frames:(size_t)frames;
- (void)stop;

@end
