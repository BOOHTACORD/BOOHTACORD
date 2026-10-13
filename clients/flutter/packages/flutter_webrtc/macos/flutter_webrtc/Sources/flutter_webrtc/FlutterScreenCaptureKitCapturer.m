#import "FlutterScreenCaptureKitCapturer.h"
#import "FlutterScreenCaptureDiagnostics.h"
#import "ScreenAudioTrackCapturer.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <math.h>

@interface FlutterScreenCaptureKitCapturer () <SCStreamOutput, SCStreamDelegate>
@property(nonatomic, strong) RTCVideoCapturer *capturer;
@property(nonatomic, weak) id<RTCVideoCapturerDelegate> delegate;
@property(nonatomic, strong) dispatch_queue_t captureQueue;
@property(nonatomic, strong) dispatch_queue_t processingQueue;
@property(nonatomic, strong) dispatch_queue_t audioQueue;
@property(nonatomic, strong) SCStream *stream API_AVAILABLE(macos(12.3));
@property(nonatomic, strong) SCStream *audioOnlyStream API_AVAILABLE(macos(13.0));
@property(nonatomic) BOOL active;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL startCompleted;
@property(nonatomic) BOOL firstFrame;
@property(nonatomic) BOOL firstFrameDelivered;
@property(nonatomic) BOOL processing;
@property(nonatomic) NSUInteger processingInFlight;
@property(nonatomic) BOOL monitorBusy;
@property(nonatomic) int64_t lastTimestampNs;
@property(nonatomic) CMSampleBufferRef pendingSample;
@property(nonatomic) uint64_t pendingReceivedNs;
@property(nonatomic, copy) void (^startCallback)(NSError *);
@property(nonatomic, strong) dispatch_source_t monitor;
@property(nonatomic, copy) NSString *selectedId;
@property(nonatomic, copy) NSString *sourceClass;
@property(nonatomic) NSInteger maximumResolution;
@property(nonatomic) NSInteger fps;
@property(nonatomic) CGSize configuredSize;
@end

@implementation FlutterScreenCaptureKitCapturer
- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate {
  if ((self = [super init])) {
    _delegate = delegate;
    _capturer = [[RTCVideoCapturer alloc] initWithDelegate:delegate];
    _captureQueue = dispatch_queue_create("boohtacord.sck.video", DISPATCH_QUEUE_SERIAL);
    _processingQueue = dispatch_queue_create("boohtacord.sck.processing", DISPATCH_QUEUE_SERIAL);
    _audioQueue = dispatch_queue_create("boohtacord.sck.audio", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}
- (NSError *)error:(NSInteger)code reason:(NSString *)reason {
  return [NSError errorWithDomain:@"FlutterScreenCaptureKit" code:code userInfo:@{NSLocalizedDescriptionKey: reason}];
}
- (BOOL)current:(NSUInteger)generation {
  @synchronized(self) { return self.active && self.generation == generation; }
}
- (uint64_t)monotonicTimeNs {
  return FlutterScreenCaptureDiagnostics.monotonicTimeNs;
}
- (CGSize)outputSizeForWidth:(CGFloat)width height:(CGFloat)height maximumResolution:(NSInteger)maximum {
  if (!isfinite(width) || !isfinite(height) || width < 2 || height < 2) return CGSizeZero;
  CGFloat scale = maximum > 0 ? MIN(1.0, (CGFloat)maximum / MAX(width, height)) : 1.0;
  return CGSizeMake(MAX(2, ((NSInteger)floor(width * scale)) & ~1), MAX(2, ((NSInteger)floor(height * scale)) & ~1));
}
- (SCDisplay *)selectDisplayFromContent:(SCShareableContent *)content sourceId:(NSString *)sourceId API_AVAILABLE(macos(12.3)) {
  if (sourceId.length > 0) {
    for (SCDisplay *display in content.displays)
      if ([[NSString stringWithFormat:@"%u", display.displayID] isEqualToString:sourceId]) return display;
    return nil;
  }
  for (SCDisplay *display in content.displays) if (display.displayID == CGMainDisplayID()) return display;
  return content.displays.firstObject;
}
- (SCWindow *)selectWindowFromContent:(SCShareableContent *)content sourceId:(NSString *)sourceId API_AVAILABLE(macos(12.3)) {
  if (sourceId.length == 0) return nil;
  for (SCWindow *window in content.windows)
    if ([[NSString stringWithFormat:@"%u", window.windowID] isEqualToString:sourceId]) return window;
  return nil;
}
- (CGFloat)scaleForDisplay:(SCDisplay *)display API_AVAILABLE(macos(12.3)) {
  CGDisplayModeRef mode = CGDisplayCopyDisplayMode(display.displayID);
  CGFloat scale = mode && display.width > 0 ? (CGFloat)CGDisplayModeGetPixelWidth(mode) / display.width : 0;
  if (mode) CGDisplayModeRelease(mode);
  return isfinite(scale) && scale > 0 ? scale : 0;
}
- (SCContentFilter *)filterFromContent:(SCShareableContent *)content size:(CGSize *)size API_AVAILABLE(macos(13.0)) {
  SCContentFilter *filter;
  CGRect points;
  CGFloat scale = 0;
  if ([self.sourceClass isEqualToString:@"window"]) {
    SCWindow *window = [self selectWindowFromContent:content sourceId:self.selectedId];
    if (!window) return nil;
    filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:window];
    points = window.frame;
    CGFloat greatestArea = 0;
    for (SCDisplay *display in content.displays) {
      CGRect intersection = CGRectIntersection(points, display.frame);
      CGFloat area = CGRectIsNull(intersection) ? 0 : intersection.size.width * intersection.size.height;
      if (area > greatestArea) { greatestArea = area; scale = [self scaleForDisplay:display]; }
    }
  } else {
    SCDisplay *display = [self selectDisplayFromContent:content sourceId:self.selectedId];
    if (!display) return nil;
    // Resolve default once. Its later disappearance must not select a new display.
    if (self.selectedId.length == 0) self.selectedId = [NSString stringWithFormat:@"%u", display.displayID];
    filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
    points = display.frame;
    scale = [self scaleForDisplay:display];
  }
  if (@available(macOS 14.0, *)) { points = filter.contentRect; scale = filter.pointPixelScale; }
  *size = [self outputSizeForWidth:points.size.width * scale height:points.size.height * scale maximumResolution:self.maximumResolution];
  return CGSizeEqualToSize(*size, CGSizeZero) ? nil : filter;
}
- (SCStreamConfiguration *)configuration:(CGSize)size API_AVAILABLE(macos(13.0)) {
  SCStreamConfiguration *config = [SCStreamConfiguration new];
  config.width = size.width; config.height = size.height;
  config.minimumFrameInterval = CMTimeMake(1, (int32_t)MAX(1, self.fps));
  config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
  config.queueDepth = 3;
  config.scalesToFit = YES; config.showsCursor = YES;
  config.colorSpaceName = kCGColorSpaceSRGB;
  config.colorMatrix = kCVImageBufferYCbCrMatrix_ITU_R_709_2;
  if (@available(macOS 14.0, *)) config.preservesAspectRatio = YES;
  if (@available(macOS 15.0, *)) config.captureDynamicRange = SCCaptureDynamicRangeSDR;
  if (self.screenAudioCapturer) {
    config.capturesAudio = YES; config.sampleRate = 48000; config.channelCount = 2;
    config.excludesCurrentProcessAudio = YES;
  }
  return config;
}
- (void)finishStart:(NSError *)error generation:(NSUInteger)generation {
  void (^callback)(NSError *);
  @synchronized(self) {
    if (self.generation != generation || !self.startCallback) return;
    if (!error && (!self.active || !self.startCompleted || !self.firstFrameDelivered)) return;
    callback = self.startCallback; self.startCallback = nil;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    callback(error ?: ([self current:generation] ? nil : [self error:-3 reason:@"Capture start cancelled"]));
  });
}
- (void)fail:(NSString *)reason generation:(NSUInteger)generation {
  if (![self current:generation]) return;
  BOOL ready;
  @synchronized(self) { ready = self.startCallback == nil && self.firstFrame; }
  [self.captureDiagnostics failWithReason:reason generation:self.diagnosticsGeneration];
  [self finishStart:[self error:-4 reason:@"Screen capture failed"] generation:generation];
  [self stopCaptureWithCompletion:^{
    if (ready && self.onCaptureEnded) dispatch_async(dispatch_get_main_queue(), self.onCaptureEnded);
  }];
}
- (void)startCaptureWithFPS:(NSInteger)fps maximumResolution:(NSInteger)maximumResolution sourceId:(NSString *)sourceId onStarted:(void (^)(NSError *))onStarted {
  [self startCaptureWithFPS:fps maximumResolution:maximumResolution sourceId:sourceId sourceClass:@"display" onStarted:onStarted];
}
- (void)startCaptureWithFPS:(NSInteger)fps maximumResolution:(NSInteger)maximumResolution sourceId:(NSString *)sourceId sourceClass:(NSString *)sourceClass onStarted:(void (^)(NSError *))onStarted {
  if (@available(macOS 13.0, *)) {
    NSUInteger generation;
    @synchronized(self) {
      if (self.active || self.processing) { onStarted([self error:-5 reason:@"Capture already active"]); return; }
      self.active = YES; self.generation++; generation = self.generation;
      self.fps = MAX(1, MIN(120, fps)); self.maximumResolution = maximumResolution;
      self.selectedId = [sourceId copy]; self.sourceClass = [sourceClass copy];
      self.startCompleted = NO; self.firstFrame = NO; self.firstFrameDelivered = NO; self.lastTimestampNs = -1; self.startCallback = onStarted;
    }
    if (![@[@"window", @"display"] containsObject:sourceClass]) { [self fail:@"source_missing" generation:generation]; return; }
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      if (![self current:generation]) return;
      if (error || !content) { [self fail:@"permission_denied" generation:generation]; return; }
      CGSize size;
      SCContentFilter *filter = [self filterFromContent:content size:&size];
      if (!filter) { [self fail:@"source_missing" generation:generation]; return; }
      SCStreamConfiguration *config = [self configuration:size];
      SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
      @synchronized(self) { if (![self current:generation]) return; self.stream = stream; self.configuredSize = size; }
      NSError *outputError = nil;
      [stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:self.captureQueue error:&outputError];
      if (!outputError && self.screenAudioCapturer)
        [stream addStreamOutput:self type:SCStreamOutputTypeAudio sampleHandlerQueue:self.audioQueue error:&outputError];
      if (outputError) { [self fail:@"start_failed" generation:generation]; return; }
      [stream startCaptureWithCompletionHandler:^(NSError *startError) {
        if (![self current:generation]) { [stream stopCaptureWithCompletionHandler:^(NSError *e) {}]; return; }
        if (startError) { [self fail:@"start_failed" generation:generation]; return; }
        @synchronized(self) { self.startCompleted = YES; }
        [self.captureDiagnostics confirmWidth:size.width height:size.height maxFPS:self.fps generation:self.diagnosticsGeneration];
        [self finishStart:nil generation:generation]; [self startMonitor:generation];
      }];
    }];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), self.captureQueue, ^{
      typeof(self) strongSelf = weakSelf;
      if ([strongSelf current:generation]) {
        @synchronized(strongSelf) { if (!strongSelf.startCallback) return; }
        [strongSelf fail:@"first_frame_timeout" generation:generation];
      }
    });
  } else onStarted([self error:-2 reason:@"ScreenCaptureKit video requires macOS 13 or later"]);
}
- (void)startMonitor:(NSUInteger)generation API_AVAILABLE(macos(13.0)) {
  @synchronized(self) {
    if (![self current:generation] || self.monitor) return;
    self.monitor = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.captureQueue);
    dispatch_source_set_timer(self.monitor, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 10);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.monitor, ^{ [weakSelf refreshSource:generation]; });
    dispatch_resume(self.monitor);
  }
}
- (void)refreshSource:(NSUInteger)generation API_AVAILABLE(macos(13.0)) {
  @synchronized(self) { if (![self current:generation] || self.monitorBusy) return; self.monitorBusy = YES; }
  [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
    @synchronized(self) { if (![self current:generation]) return; }
    if (error || !content) { [self fail:@"permission_denied" generation:generation]; return; }
    CGSize size;
    SCContentFilter *filter = [self filterFromContent:content size:&size];
    if (!filter) { [self fail:@"source_missing" generation:generation]; return; }
    SCStream *stream;
    @synchronized(self) {
      if (CGSizeEqualToSize(size, self.configuredSize)) { self.monitorBusy = NO; return; }
      stream = self.stream;
    }
    [stream updateContentFilter:filter completionHandler:^(NSError *filterError) {
      if (![self current:generation]) return;
      if (filterError) { [self fail:@"configuration_failed" generation:generation]; return; }
      [stream updateConfiguration:[self configuration:size] completionHandler:^(NSError *configError) {
        if (![self current:generation]) return;
        if (configError) { [self fail:@"configuration_failed" generation:generation]; return; }
        @synchronized(self) { self.configuredSize = size; self.monitorBusy = NO; }
        [self.captureDiagnostics confirmWidth:size.width height:size.height maxFPS:self.fps generation:self.diagnosticsGeneration];
      }];
    }];
  }];
}
- (void)startAudioCaptureWithSourceId:(NSString *)sourceId onStarted:(void (^)(NSError *))onStarted {
  if (@available(macOS 13.0, *)) {
    NSUInteger generation;
    @synchronized(self) { self.active = YES; self.generation++; generation = self.generation; self.fps = 1; }
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      if (![self current:generation]) { onStarted([self error:-3 reason:@"Audio capture cancelled"]); return; }
      SCDisplay *display = error ? nil : [self selectDisplayFromContent:content sourceId:sourceId];
      if (!display) { [self stopCaptureWithCompletion:^{ onStarted([self error:-1 reason:@"Audio capture source unavailable"]); }]; return; }
      SCStream *stream = [[SCStream alloc] initWithFilter:[[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]]
          configuration:[self configuration:CGSizeMake(2, 2)] delegate:self];
      @synchronized(self) { if (![self current:generation]) return; self.audioOnlyStream = stream; }
      NSError *outputError = nil;
      [stream addStreamOutput:self type:SCStreamOutputTypeAudio sampleHandlerQueue:self.audioQueue error:&outputError];
      if (outputError) { [self stopCaptureWithCompletion:^{ onStarted([self error:-4 reason:@"Audio capture failed"]); }]; return; }
      [stream startCaptureWithCompletionHandler:^(NSError *startError) {
        if (![self current:generation]) { [stream stopCaptureWithCompletionHandler:^(NSError *e) {}]; onStarted([self error:-3 reason:@"Audio capture cancelled"]); return; }
        if (startError) [self stopCaptureWithCompletion:^{ onStarted([self error:-4 reason:@"Audio capture failed"]); }];
        else onStarted(nil);
      }];
    }];
  } else onStarted([self error:-2 reason:@"System audio capture requires macOS 13 or later"]);
}
- (void)stopCaptureWithCompletion:(void (^)(void))completion {
  id video = nil, audio = nil;
  void (^pending)(NSError *);
  @synchronized(self) {
    self.active = NO; self.generation++; self.monitorBusy = NO;
    if (self.monitor) { dispatch_source_cancel(self.monitor); self.monitor = nil; }
    if (self.pendingSample) { CFRelease(self.pendingSample); self.pendingSample = NULL; }
    pending = self.startCallback; self.startCallback = nil;
    if (@available(macOS 12.3, *)) { video = self.stream; self.stream = nil; }
    if (@available(macOS 13.0, *)) { audio = self.audioOnlyStream; self.audioOnlyStream = nil; }
  }
  [self.captureDiagnostics stop];
  if (pending) dispatch_async(dispatch_get_main_queue(), ^{ pending([self error:-3 reason:@"Capture start cancelled"]); });
  dispatch_group_t group = dispatch_group_create();
  for (id stream in @[video ?: (id)NSNull.null, audio ?: (id)NSNull.null]) {
    if ((id)stream == NSNull.null) continue;
    if (@available(macOS 12.3, *)) {
      dispatch_group_enter(group);
      [stream stopCaptureWithCompletionHandler:^(NSError *error) { dispatch_group_leave(group); }];
    }
  }
  // Queue fences ensure previously accepted callbacks cannot outlive completion.
  dispatch_group_notify(group, self.processingQueue, ^{
    dispatch_async(self.audioQueue, ^{ [self.screenAudioCapturer stop]; completion(); });
  });
}
- (BOOL)ownsStream:(SCStream *)stream API_AVAILABLE(macos(12.3)) {
  BOOL owned = stream == self.stream;
  if (@available(macOS 13.0, *)) owned = owned || stream == self.audioOnlyStream;
  return owned;
}
- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error API_AVAILABLE(macos(12.3)) {
  NSUInteger generation;
  @synchronized(self) { if (!self.active || ![self ownsStream:stream]) return; generation = self.generation; }
  [self fail:@"stream_stopped" generation:generation];
}
- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sample ofType:(SCStreamOutputType)type API_AVAILABLE(macos(12.3)) {
  NSUInteger generation;
  @synchronized(self) {
    if (!self.active || ![self ownsStream:stream]) return;
    generation = self.generation;
  }
  if (!sample || !CMSampleBufferIsValid(sample) || !CMSampleBufferDataIsReady(sample)) {
    if (type == SCStreamOutputTypeScreen) [self.captureDiagnostics dropReason:FlutterCaptureDropInvalid generation:self.diagnosticsGeneration];
    return;
  }
  if (@available(macOS 13.0, *)) {
    if (type == SCStreamOutputTypeAudio) {
      if (![self.screenAudioCapturer appendSampleBuffer:sample])
        [self fail:@"audio_format_unsupported" generation:generation];
      return;
    }
  }
  if (type != SCStreamOutputTypeScreen || stream != self.stream) return;
  CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, NO);
  NSDictionary *info = attachments && CFArrayGetCount(attachments) > 0 ? (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachments, 0) : nil;
  NSNumber *status = info[SCStreamFrameInfoStatus];
  if (!status || status.integerValue != SCFrameStatusComplete) {
    [self.captureDiagnostics dropReason:(status && status.integerValue == SCFrameStatusIdle) ? FlutterCaptureDropIdle : FlutterCaptureDropIncomplete generation:self.diagnosticsGeneration]; return;
  }
  CVPixelBufferRef pixel = CMSampleBufferGetImageBuffer(sample);
  if (!pixel || CVPixelBufferGetWidth(pixel) < 2 || CVPixelBufferGetHeight(pixel) < 2
      || ![RTCCVPixelBuffer.supportedPixelFormats containsObject:@(CVPixelBufferGetPixelFormatType(pixel))]) {
    [self.captureDiagnostics dropReason:FlutterCaptureDropInvalid generation:self.diagnosticsGeneration]; return;
  }
  size_t width = CVPixelBufferGetWidth(pixel), height = CVPixelBufferGetHeight(pixel);
  BOOL strideValid;
  if (CVPixelBufferIsPlanar(pixel)) {
    strideValid = CVPixelBufferGetPlaneCount(pixel) == 2
        && CVPixelBufferGetBytesPerRowOfPlane(pixel, 0) >= width
        && CVPixelBufferGetBytesPerRowOfPlane(pixel, 1) >= width
        && CVPixelBufferGetHeightOfPlane(pixel, 0) >= height
        && CVPixelBufferGetHeightOfPlane(pixel, 1) >= (height + 1) / 2;
  } else strideValid = CVPixelBufferGetBytesPerRow(pixel) >= width * 4;
  if (!strideValid) {
    [self.captureDiagnostics dropReason:FlutterCaptureDropInvalid generation:self.diagnosticsGeneration]; return;
  }
  CMTime pts = CMSampleBufferGetPresentationTimeStamp(sample);
  double seconds = CMTimeGetSeconds(pts);
  if (!CMTIME_IS_NUMERIC(pts) || !isfinite(seconds) || seconds < 0 || seconds >= (double)INT64_MAX / 1000000000.0) {
    [self.captureDiagnostics dropReason:FlutterCaptureDropTimestamp generation:self.diagnosticsGeneration]; return;
  }
  int64_t ns = (int64_t)(seconds * 1000000000.0);
  @synchronized(self) {
    if (![self current:generation] || stream != self.stream) return;
    if (self.firstFrame && ns <= self.lastTimestampNs) { [self.captureDiagnostics dropReason:FlutterCaptureDropTimestamp generation:self.diagnosticsGeneration]; return; }
    self.lastTimestampNs = ns; self.firstFrame = YES;
    [self.captureDiagnostics acceptWidth:CVPixelBufferGetWidth(pixel) height:CVPixelBufferGetHeight(pixel)
        pixelFormat:CVPixelBufferGetPixelFormatType(pixel) rotation:0 generation:self.diagnosticsGeneration];
    if (self.pendingSample) { CFRelease(self.pendingSample); [self.captureDiagnostics dropReason:FlutterCaptureDropQueue generation:self.diagnosticsGeneration]; }
    self.pendingSample = (CMSampleBufferRef)CFRetain(sample);
    self.pendingReceivedNs = [self monotonicTimeNs];
    [self.captureDiagnostics queueDepth:1 inFlight:self.processingInFlight + 1 ageNs:0 generation:self.diagnosticsGeneration];
    if (self.processing) return;
    self.processing = YES;
  }
  dispatch_async(self.processingQueue, ^{ [self drainFrames:generation]; });
}
- (void)drainFrames:(NSUInteger)generation {
  while (YES) {
    CMSampleBufferRef sample;
    uint64_t received;
    @synchronized(self) {
      if (![self current:generation] || !self.pendingSample) {
        self.processing = NO; self.processingInFlight = 0;
        [self.captureDiagnostics queueDepth:0 inFlight:0 ageNs:0 generation:self.diagnosticsGeneration];
        return;
      }
      sample = self.pendingSample; self.pendingSample = NULL; received = self.pendingReceivedNs;
      self.processingInFlight = 1;
    }
    uint64_t age = [self monotonicTimeNs] - received;
    [self.captureDiagnostics queueDepth:0 inFlight:1 ageNs:age generation:self.diagnosticsGeneration];
    if (age > 100 * NSEC_PER_MSEC) {
      [self.captureDiagnostics dropReason:FlutterCaptureDropQueue generation:self.diagnosticsGeneration];
      CFRelease(sample);
      @synchronized(self) { self.processingInFlight = 0; }
      continue;
    }
    CVPixelBufferRef pixel = CMSampleBufferGetImageBuffer(sample);
    RTCCVPixelBuffer *buffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixel];
    RTCVideoFrame *frame = [[RTCVideoFrame alloc] initWithBuffer:buffer rotation:RTCVideoRotation_0
        timeStampNs:(int64_t)(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)) * 1000000000.0)];
    if ([self current:generation]) {
      [self.delegate capturer:self.capturer didCaptureVideoFrame:frame];
      @synchronized(self) { if ([self current:generation]) self.firstFrameDelivered = YES; }
    }
    CFRelease(sample);
    @synchronized(self) {
      self.processingInFlight = 0;
      [self.captureDiagnostics queueDepth:self.pendingSample ? 1 : 0 inFlight:self.pendingSample ? 1 : 0
          ageNs:age generation:self.diagnosticsGeneration];
    }
    [self finishStart:nil generation:generation];
  }
}
@end
