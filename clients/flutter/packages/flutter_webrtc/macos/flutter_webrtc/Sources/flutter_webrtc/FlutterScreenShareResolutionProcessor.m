#import "FlutterScreenShareResolutionProcessor.h"
#import "FlutterScreenCaptureDiagnostics.h"
@import CoreImage;
@import CoreVideo;

@implementation FlutterScreenShareResolutionProcessor {
  NSInteger _maximumResolution;
  CIContext *_context;
  CGColorSpaceRef _colorSpace;
  CVPixelBufferPoolRef _pool;
  size_t _poolWidth, _poolHeight;
  CVPixelBufferRef _seen[4];
  NSUInteger _seenCount;
  NSDictionary *_poolLimit, *_outputAttachments;
}
- (instancetype)initWithMaximumResolution:(NSInteger)maximumResolution {
  if ((self = [super init])) {
    _maximumResolution = MAX(0, maximumResolution);
    _context = [CIContext contextWithOptions:nil];
    _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    _poolLimit = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @4};
  }
  return self;
}
- (void)dealloc {
  if (_pool) CVPixelBufferPoolRelease(_pool);
  if (_colorSpace) CGColorSpaceRelease(_colorSpace);
}
- (CVPixelBufferRef)acquireWidth:(size_t)width height:(size_t)height {
  if (_pool && (_poolWidth != width || _poolHeight != height)) {
    CVPixelBufferPoolRelease(_pool); _pool = NULL;
  }
  if (!_pool) {
    NSDictionary *attributes = @{
      (id)kCVPixelBufferWidthKey: @(width), (id)kCVPixelBufferHeightKey: @(height),
      (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
      (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
      (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
      (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };
    CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
        (__bridge CFDictionaryRef)attributes, &_pool);
    if (status != kCVReturnSuccess || !_pool) return NULL;
    _poolWidth = width; _poolHeight = height;
    _outputAttachments = @{
      (id)kCVImageBufferCGColorSpaceKey: (__bridge id)_colorSpace,
      (id)kCVImageBufferColorPrimariesKey: (id)kCVImageBufferColorPrimaries_ITU_R_709_2,
      (id)kCVImageBufferTransferFunctionKey: (id)kCVImageBufferTransferFunction_sRGB,
      (id)kCVImageBufferCleanApertureKey: @{
        (id)kCVImageBufferCleanApertureWidthKey: @(width), (id)kCVImageBufferCleanApertureHeightKey: @(height),
        (id)kCVImageBufferCleanApertureHorizontalOffsetKey: @0, (id)kCVImageBufferCleanApertureVerticalOffsetKey: @0,
      },
      (id)kCVImageBufferDisplayDimensionsKey: @{
        (id)kCVImageBufferDisplayWidthKey: @(width), (id)kCVImageBufferDisplayHeightKey: @(height),
      },
    };
    _seenCount = 0;
    [self.captureDiagnostics operation:FlutterCapturePoolCreated generation:self.diagnosticsGeneration];
  }
  CVPixelBufferRef output = NULL;
  CVReturn status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
      kCFAllocatorDefault, _pool, (__bridge CFDictionaryRef)_poolLimit, &output);
  if (status != kCVReturnSuccess) return NULL;
  [self.captureDiagnostics operation:FlutterCapturePoolAcquire generation:self.diagnosticsGeneration];
  BOOL seen = NO;
  for (NSUInteger i = 0; i < _seenCount; i++) if (_seen[i] == output) seen = YES;
  if (!seen && _seenCount < 4) {
    _seen[_seenCount++] = output;
    [self.captureDiagnostics operation:FlutterCapturePoolBufferFirstSeen generation:self.diagnosticsGeneration];
  }
  return output;
}
- (RTCVideoFrame *)failedFrame {
  [self.captureDiagnostics operation:FlutterCaptureProcessingFailure generation:self.diagnosticsGeneration];
  return nil;
}
- (RTCVideoFrame *)onFrame:(RTCVideoFrame *)frame {
  NSInteger sourceLongEdge = MAX(frame.width, frame.height);
  if (_maximumResolution <= 0 || sourceLongEdge <= _maximumResolution) {
    [self.captureDiagnostics operation:FlutterCapturePassThrough generation:self.diagnosticsGeneration];
    return frame;
  }
  if (frame.width < 2 || frame.height < 2) return [self failedFrame];
  CGFloat scale = (CGFloat)_maximumResolution / sourceLongEdge;
  size_t width = MAX(2, ((size_t)(frame.width * scale)) & ~((size_t)1));
  size_t height = MAX(2, ((size_t)(frame.height * scale)) & ~((size_t)1));
  if (width > 8192 || height > 8192) return [self failedFrame];

  if (![frame.buffer isKindOfClass:RTCCVPixelBuffer.class]) {
    // Ask the native buffer to scale directly. An I420 fallback stays I420;
    // never allocate full-size BGRA merely to scale it back down.
    id<RTCVideoFrameBuffer> buffer = frame.buffer;
    SEL scaler = @selector(cropAndScaleWith:offsetY:cropWidth:cropHeight:scaleWidth:scaleHeight:);
    if (![buffer respondsToSelector:scaler]) buffer = [buffer toI420];
    if (![buffer respondsToSelector:scaler]) return [self failedFrame];
    id<RTCVideoFrameBuffer> scaled = [buffer cropAndScaleWith:0 offsetY:0 cropWidth:frame.width
        cropHeight:frame.height scaleWidth:(int)width scaleHeight:(int)height];
    if (!scaled || scaled.width != width || scaled.height != height) return [self failedFrame];
    [self.captureDiagnostics operation:FlutterCaptureI420Scale generation:self.diagnosticsGeneration];
    return [[RTCVideoFrame alloc] initWithBuffer:scaled rotation:frame.rotation timeStampNs:frame.timeStampNs];
  }

  RTCCVPixelBuffer *native = (RTCCVPixelBuffer *)frame.buffer;
  CVPixelBufferRef source = native.pixelBuffer;
  if (!source) return [self failedFrame];
  CVPixelBufferRef output = [self acquireWidth:width height:height];
  if (!output) return [self failedFrame]; // Never oversized output on exhaustion.
  @try {
    CIImage *image = [CIImage imageWithCVPixelBuffer:source];
    CGRect crop = CGRectMake(native.cropX, native.cropY, native.cropWidth, native.cropHeight);
    image = [image imageByCroppingToRect:crop];
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-crop.origin.x, -crop.origin.y)];
    image = [image imageByApplyingTransform:CGAffineTransformMakeScale((CGFloat)width / crop.size.width, (CGFloat)height / crop.size.height)];
    [_context render:image toCVPixelBuffer:output bounds:CGRectMake(0, 0, width, height) colorSpace:_colorSpace];
  } @catch (NSException *exception) {
    CVPixelBufferRelease(output); return [self failedFrame];
  }
  // A pooled resized RGB buffer must not inherit the source's old color space,
  // HDR or geometry labels. CI rendered this buffer explicitly into sRGB.
  CVBufferRemoveAllAttachments(output);
  CVBufferSetAttachments(output, (__bridge CFDictionaryRef)_outputAttachments, kCVAttachmentMode_ShouldPropagate);
  RTCCVPixelBuffer *buffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:output];
  RTCVideoFrame *scaled = [[RTCVideoFrame alloc] initWithBuffer:buffer rotation:frame.rotation timeStampNs:frame.timeStampNs];
  CVPixelBufferRelease(output);
  [self.captureDiagnostics operation:FlutterCaptureNativeResize generation:self.diagnosticsGeneration];
  return scaled;
}
@end
