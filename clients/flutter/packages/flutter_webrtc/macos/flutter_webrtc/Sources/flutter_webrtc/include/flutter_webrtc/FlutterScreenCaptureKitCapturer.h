#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@class FlutterScreenAudioTrackCapturer;
@class FlutterScreenCaptureDiagnostics;

@interface FlutterScreenCaptureKitCapturer : NSObject

@property(nonatomic, strong, nullable) FlutterScreenAudioTrackCapturer *screenAudioCapturer;
@property(nonatomic, strong, nullable) FlutterScreenCaptureDiagnostics *captureDiagnostics;
@property(nonatomic) NSUInteger diagnosticsGeneration;
@property(nonatomic, copy, nullable) void (^onCaptureEnded)(void);

- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate;

- (void)startCaptureWithFPS:(NSInteger)fps
         maximumResolution:(NSInteger)maximumResolution
                   sourceId:(NSString* _Nullable)sourceId
                  onStarted:(void (^ _Nonnull)(NSError * _Nullable error))onStarted;

- (void)startCaptureWithFPS:(NSInteger)fps
         maximumResolution:(NSInteger)maximumResolution
                   sourceId:(NSString* _Nullable)sourceId
                sourceClass:(NSString *)sourceClass
                  onStarted:(void (^ _Nonnull)(NSError * _Nullable error))onStarted;

- (void)stopCaptureWithCompletion:(void (^ _Nonnull)(void))completion;

- (void)startAudioCaptureWithSourceId:(NSString * _Nullable)sourceId
                            onStarted:(void (^ _Nonnull)(NSError * _Nullable error))onStarted;

@end

NS_ASSUME_NONNULL_END
