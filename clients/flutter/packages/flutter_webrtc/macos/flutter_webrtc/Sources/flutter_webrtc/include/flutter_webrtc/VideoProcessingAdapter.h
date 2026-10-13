#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
@class FlutterScreenCaptureDiagnostics;

@protocol ExternalVideoProcessingDelegate
- (RTC_OBJC_TYPE(RTCVideoFrame) * _Nullable)onFrame:(RTC_OBJC_TYPE(RTCVideoFrame) * _Nonnull)frame;
@end

@interface VideoProcessingAdapter : NSObject <RTCVideoCapturerDelegate>
@property(nonatomic, strong, nullable) FlutterScreenCaptureDiagnostics *captureDiagnostics;
@property(nonatomic) NSUInteger captureGeneration;
@property(nonatomic) BOOL captureRecordsSourceFrames;
@property(atomic) BOOL captureStopped;

- (_Nonnull instancetype)initWithRTCVideoSource:(RTCVideoSource* _Nonnull)source;

- (void)addProcessing:(_Nonnull id<ExternalVideoProcessingDelegate>)processor;

- (void)removeProcessing:(_Nonnull id<ExternalVideoProcessingDelegate>)processor;

- (RTCVideoSource* _Nonnull) source;

@end
