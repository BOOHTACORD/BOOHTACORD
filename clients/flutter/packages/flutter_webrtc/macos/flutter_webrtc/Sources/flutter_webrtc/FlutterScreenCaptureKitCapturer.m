#import "FlutterScreenCaptureKitCapturer.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import "ScreenAudioTrackCapturer.h"

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#endif

@interface FlutterScreenCaptureKitCapturer ()
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
<SCStreamOutput>
#endif
@property(nonatomic, strong) RTCVideoCapturer *capturer;
@property(nonatomic, weak) id<RTCVideoCapturerDelegate> delegate;
@property(nonatomic, strong) dispatch_queue_t captureQueue;
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
@property(nonatomic, strong) SCStream *stream API_AVAILABLE(macos(12.3));
@property(nonatomic, strong) SCStream *audioOnlyStream API_AVAILABLE(macos(13.0));
#endif
@end

@implementation FlutterScreenCaptureKitCapturer

- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _capturer = [[RTCVideoCapturer alloc] initWithDelegate:delegate];
    _captureQueue = dispatch_queue_create("com.iperius.sck.capture", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)startCaptureWithFPS:(NSInteger)fps
         maximumResolution:(NSInteger)maximumResolution
                   sourceId:(NSString* _Nullable)sourceId
                  onStarted:(void (^)(NSError * _Nullable error))onStarted {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 12.3, *)) {
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      if (error != nil) {
        onStarted(error);
        return;
      }

      SCDisplay *display = [self selectDisplayFromContent:content sourceId:sourceId];
      if (display == nil) {
        NSError *noDisplay = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"No matching display"}];
        onStarted(noDisplay);
        return;
      }

      SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
      SCStreamConfiguration *config = [SCStreamConfiguration new];
      CGFloat scale = 1.0;
      NSInteger sourceLongEdge = MAX(display.width, display.height);
      if (maximumResolution > 0 && sourceLongEdge > maximumResolution) {
        scale = (CGFloat)maximumResolution / sourceLongEdge;
      }
      // Preserve the source aspect ratio. ScreenCaptureKit scales its output
      // buffer to this size; never force the profile's 16:9 dimensions onto a
      // portrait or non-16:9 display.
      config.width = MAX(2, ((NSInteger)(display.width * scale)) & ~1);
      config.height = MAX(2, ((NSInteger)(display.height * scale)) & ~1);
      config.minimumFrameInterval = CMTimeMake(1, (int32_t)MAX(1, fps));
      config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
      if (@available(macOS 13.0, *)) {
        config.showsCursor = YES;
        if (self.screenAudioCapturer != nil) {
          config.capturesAudio = YES;
          config.sampleRate = 48000;
          config.channelCount = 2;
          config.excludesCurrentProcessAudio = YES;
        }
      }

      self.stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:nil];
      NSLog(@"ScreenCaptureKit output: %ldx%ld (source %ldx%ld, profile long edge %ld)",
            (long)config.width, (long)config.height, (long)display.width,
            (long)display.height, (long)maximumResolution);
      NSError *addOutputError = nil;
      [self.stream addStreamOutput:self
                              type:SCStreamOutputTypeScreen
               sampleHandlerQueue:self.captureQueue
                            error:&addOutputError];
      if (addOutputError != nil) {
        onStarted(addOutputError);
        return;
      }
      if (@available(macOS 13.0, *)) {
        if (self.screenAudioCapturer != nil) {
          [self.stream addStreamOutput:self
                                  type:SCStreamOutputTypeAudio
                   sampleHandlerQueue:self.captureQueue
                                error:&addOutputError];
          if (addOutputError != nil) {
            onStarted(addOutputError);
            return;
          }
        }
      }

      [self.stream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
        onStarted(startError);
      }];
    }];
    return;
  }
#endif

  NSError *unavailable = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"ScreenCaptureKit not available"}];
  onStarted(unavailable);
}

- (void)stopCaptureWithCompletion:(void (^)(void))completion {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 12.3, *)) {
    SCStream *videoStream = self.stream;
    self.stream = nil;
    SCStream *audioStream = nil;
    if (@available(macOS 13.0, *)) {
      audioStream = self.audioOnlyStream;
      self.audioOnlyStream = nil;
    }
    if (videoStream == nil && audioStream == nil) {
      [self.screenAudioCapturer stop];
      completion();
      return;
    }
    dispatch_group_t stopGroup = dispatch_group_create();
    if (videoStream != nil) {
      dispatch_group_enter(stopGroup);
      [videoStream stopCaptureWithCompletionHandler:^(__unused NSError * _Nullable error) {
        dispatch_group_leave(stopGroup);
      }];
    }
    if (audioStream != nil) {
      dispatch_group_enter(stopGroup);
      [audioStream stopCaptureWithCompletionHandler:^(__unused NSError * _Nullable error) {
        dispatch_group_leave(stopGroup);
      }];
    }
    dispatch_group_notify(stopGroup, self.captureQueue, ^{
      [self.screenAudioCapturer stop];
      completion();
    });
    return;
  }
#endif
  [self.screenAudioCapturer stop];
  completion();
}

- (void)startAudioCaptureWithSourceId:(NSString *)sourceId
                            onStarted:(void (^)(NSError * _Nullable))onStarted {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 13.0, *)) {
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      if (error != nil) {
        onStarted(error);
        return;
      }
      SCDisplay *display = [self selectDisplayFromContent:content sourceId:sourceId];
      if (display == nil) {
        NSError *noDisplay = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                                 code:-1
                                             userInfo:@{@"NSLocalizedDescriptionKey" : @"No matching display"}];
        onStarted(noDisplay);
        return;
      }
      SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
      SCStreamConfiguration *config = [SCStreamConfiguration new];
      config.width = 2;
      config.height = 2;
      config.capturesAudio = YES;
      config.sampleRate = 48000;
      config.channelCount = 2;
      config.excludesCurrentProcessAudio = YES;
      self.audioOnlyStream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:nil];
      NSError *addError = nil;
      [self.audioOnlyStream addStreamOutput:self
                                       type:SCStreamOutputTypeAudio
                        sampleHandlerQueue:self.captureQueue
                                     error:&addError];
      if (addError != nil) {
        self.audioOnlyStream = nil;
        onStarted(addError);
        return;
      }
      [self.audioOnlyStream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
        onStarted(startError);
      }];
    }];
    return;
  }
#endif
  NSError *unavailable = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                             code:-2
                                         userInfo:@{@"NSLocalizedDescriptionKey" : @"System audio capture requires macOS 13 or later"}];
  onStarted(unavailable);
}

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
- (SCDisplay *)selectDisplayFromContent:(SCShareableContent *)content
                               sourceId:(NSString *)sourceId API_AVAILABLE(macos(12.3)) {
  if (content.displays.count == 0) {
    return nil;
  }

  if (sourceId != nil && sourceId.length > 0) {
    for (SCDisplay *display in content.displays) {
      if ([[NSString stringWithFormat:@"%u", display.displayID] isEqualToString:sourceId]) {
        return display;
      }
    }
  }

  CGDirectDisplayID mainDisplay = CGMainDisplayID();
  for (SCDisplay *display in content.displays) {
    if (display.displayID == mainDisplay) {
      return display;
    }
  }

  return content.displays.firstObject;
}

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type API_AVAILABLE(macos(12.3)) {
  if (@available(macOS 13.0, *)) {
    if (type == SCStreamOutputTypeAudio) {
      [self.screenAudioCapturer appendSampleBuffer:sampleBuffer];
      return;
    }
  }
  if (type != SCStreamOutputTypeScreen) {
    return;
  }

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    return;
  }

  CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  int64_t timeStampNs = (int64_t)(CMTimeGetSeconds(timestamp) * 1000000000.0);

  id<RTCVideoFrameBuffer> rtcBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
  RTCVideoFrame *frame = [[RTCVideoFrame alloc] initWithBuffer:rtcBuffer
                                                      rotation:RTCVideoRotation_0
                                                   timeStampNs:timeStampNs];
  [self.delegate capturer:self.capturer didCaptureVideoFrame:frame];
}
#endif

@end
