#import "VideoProcessingAdapter.h"
#import <os/lock.h>
#import "FlutterScreenCaptureDiagnostics.h"

@implementation VideoProcessingAdapter {
  RTCVideoSource* _videoSource;
  CGSize _frameSize;
  NSArray<id<ExternalVideoProcessingDelegate>>* _processors;
  os_unfair_lock _lock;
}

- (instancetype)initWithRTCVideoSource:(RTCVideoSource*)source {
  self = [super init];
  if (self) {
    _lock = OS_UNFAIR_LOCK_INIT;
    _videoSource = source;
    _processors = [NSArray<id<ExternalVideoProcessingDelegate>> new];
    _captureRecordsSourceFrames = YES;
  }
  return self;
}

- (RTCVideoSource* _Nonnull) source {
    return _videoSource;
}

- (void)addProcessing:(id<ExternalVideoProcessingDelegate>)processor {
  os_unfair_lock_lock(&_lock);
  _processors = [_processors arrayByAddingObject:processor];
  os_unfair_lock_unlock(&_lock);
}

- (void)removeProcessing:(id<ExternalVideoProcessingDelegate>)processor {
  os_unfair_lock_lock(&_lock);
  _processors = [_processors
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject,
                                                                        NSDictionary* bindings) {
        return evaluatedObject != processor;
      }]];
  os_unfair_lock_unlock(&_lock);
}

- (void)setSize:(CGSize)size {
  _frameSize = size;
}

- (void)capturer:(RTC_OBJC_TYPE(RTCVideoCapturer) *)capturer
    didCaptureVideoFrame:(RTC_OBJC_TYPE(RTCVideoFrame) *)frame {
  if (self.captureStopped) return;
  FlutterScreenCaptureDiagnostics *diagnostics = self.captureDiagnostics;
  uint64_t startedNs = diagnostics ? [FlutterScreenCaptureDiagnostics monotonicTimeNs] : 0;
  uint32_t inputFormat = diagnostics && [frame.buffer isKindOfClass:RTCCVPixelBuffer.class]
      ? CVPixelBufferGetPixelFormatType(((RTCCVPixelBuffer *)frame.buffer).pixelBuffer) : 0;
  if (self.captureRecordsSourceFrames) {
    [self.captureDiagnostics acceptWidth:frame.width height:frame.height pixelFormat:inputFormat
                               rotation:frame.rotation generation:self.captureGeneration];
  }
  os_unfair_lock_lock(&_lock);
  for (id<ExternalVideoProcessingDelegate> processor in _processors) {
    frame = [processor onFrame:frame];
    if (!frame) break;
  }
  if (frame && !self.captureStopped) [_videoSource capturer:capturer didCaptureVideoFrame:frame];
  os_unfair_lock_unlock(&_lock);
  if (!frame || self.captureStopped) {
    [diagnostics dropReason:FlutterCaptureDropProcessing generation:self.captureGeneration];
    return;
  }
  uint32_t outputFormat = diagnostics && [frame.buffer isKindOfClass:RTCCVPixelBuffer.class]
      ? CVPixelBufferGetPixelFormatType(((RTCCVPixelBuffer *)frame.buffer).pixelBuffer) : 0;
  if (diagnostics) [diagnostics deliverWidth:frame.width height:frame.height pixelFormat:outputFormat
                              rotation:frame.rotation processingNs:[FlutterScreenCaptureDiagnostics monotonicTimeNs] - startedNs
                            generation:self.captureGeneration];
}

@end
