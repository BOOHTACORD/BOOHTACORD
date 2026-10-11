#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@class FlutterScreenAudioTrackCapturer;

@interface FlutterScreenCaptureKitCapturer : NSObject

@property(nonatomic, strong, nullable) FlutterScreenAudioTrackCapturer *screenAudioCapturer;

- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate;

- (void)startCaptureWithFPS:(NSInteger)fps
         maximumResolution:(NSInteger)maximumResolution
                   sourceId:(NSString* _Nullable)sourceId
                  onStarted:(void (^ _Nonnull)(NSError * _Nullable error))onStarted;

- (void)stopCaptureWithCompletion:(void (^ _Nonnull)(void))completion;

- (void)startAudioCaptureWithSourceId:(NSString * _Nullable)sourceId
                            onStarted:(void (^ _Nonnull)(NSError * _Nullable error))onStarted;

@end

NS_ASSUME_NONNULL_END
