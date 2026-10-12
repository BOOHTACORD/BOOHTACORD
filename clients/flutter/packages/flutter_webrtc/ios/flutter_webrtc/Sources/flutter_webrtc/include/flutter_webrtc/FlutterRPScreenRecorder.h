#if TARGET_OS_IPHONE
#import <WebRTC/WebRTC.h>

@class FlutterScreenAudioTrackCapturer;

@interface FlutterRPScreenRecorder : RTCVideoCapturer

@property(nonatomic, strong) FlutterScreenAudioTrackCapturer *screenAudioCapturer;

- (void)startCapture;

// Stops the capture session asynchronously and notifies callback on completion.
- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler;

- (void)stopCapture;

@end
#endif
