// Synthetic boundary tests for the actual vendored macOS capturer. No OS capture.
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import "FlutterScreenCaptureKitCapturer.h"

@interface FlutterScreenCaptureKitCapturer (BoundaryTest)
- (SCDisplay *)selectDisplayFromContent:(SCShareableContent *)content sourceId:(NSString *)sourceId;
- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type;
- (SCWindow *)selectWindowFromContent:(SCShareableContent *)content sourceId:(NSString *)sourceId;
- (CGSize)outputSizeForWidth:(CGFloat)width height:(CGFloat)height maximumResolution:(NSInteger)maximum;
@end

// Only selection records and stream identity are synthetic. Frame wrapping uses
// the real CoreVideo/CoreMedia and pinned WebRTC framework implementations.
@interface DisplayRecord : NSObject
@property(nonatomic) CGDirectDisplayID displayID;
@end
@implementation DisplayRecord
@end
@interface WindowRecord : NSObject
@property(nonatomic) CGWindowID windowID;
@end
@implementation WindowRecord
@end
@interface ContentRecord : NSObject
@property(nonatomic, strong) NSArray *displays;
@property(nonatomic, strong) NSArray *windows;
@end
@implementation ContentRecord
@end
@interface FrameSink : NSObject <RTCVideoCapturerDelegate>
@property(nonatomic, strong) NSMutableArray<RTCVideoFrame *> *frames;
@end
@implementation FrameSink
- (instancetype)init { if ((self = [super init])) _frames = [NSMutableArray new]; return self; }
- (void)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame {
  [self.frames addObject:frame];
}
@end

static CMSampleBufferRef sample(CMTime pts, NSNumber *status) {
  CVPixelBufferRef pixel = NULL;
  OSStatus result = CVPixelBufferCreate(kCFAllocatorDefault, 64, 32,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      (__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &pixel);
  NSCAssert(result == kCVReturnSuccess, @"synthetic pixel allocation failed");
  CMVideoFormatDescriptionRef format = NULL;
  result = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &format);
  NSCAssert(result == noErr, @"synthetic video format failed");
  CMSampleTimingInfo timing = {CMTimeMake(1, 30), pts, kCMTimeInvalid};
  CMSampleBufferRef buffer = NULL;
  result = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixel, format, &timing, &buffer);
  NSCAssert(result == noErr, @"synthetic video sample failed");
  if (status != nil) {
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, YES);
    CFMutableDictionaryRef info = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(info, (__bridge CFStringRef)SCStreamFrameInfoStatus, (__bridge CFNumberRef)status);
  }
  CFRelease(format);
  CVPixelBufferRelease(pixel);
  return buffer;
}

static NSMutableArray *cases;
static void check(NSString *name, BOOL passed) {
  [cases addObject:@{@"name": name, @"status": passed ? @"PASS" : @"FAIL"}];
}

static FlutterScreenCaptureKitCapturer *active(FrameSink *sink, NSObject **identity) {
  FlutterScreenCaptureKitCapturer *capture = [[FlutterScreenCaptureKitCapturer alloc] initWithDelegate:sink];
  *identity = [NSObject new];
  // Assign the private stream identity without requesting permissions or starting
  // a stream. This test does not prove startup, queue timing or OS behavior.
  [capture setValue:*identity forKey:@"stream"];
  [capture setValue:@YES forKey:@"active"];
  return capture;
}

static void deliver(FlutterScreenCaptureKitCapturer *capture, NSObject *identity,
                    CMTime pts, NSNumber *status) {
  CMSampleBufferRef buffer = sample(pts, status);
  [capture stream:(SCStream *)identity didOutputSampleBuffer:buffer ofType:SCStreamOutputTypeScreen];
  CFRelease(buffer);
  dispatch_sync([capture valueForKey:@"processingQueue"], ^{});
}

int main(void) {
  @autoreleasepool {
    cases = [NSMutableArray new];
    FrameSink *sink = [FrameSink new];
    FlutterScreenCaptureKitCapturer *capture = [[FlutterScreenCaptureKitCapturer alloc] initWithDelegate:sink];
    DisplayRecord *first = [DisplayRecord new]; first.displayID = 100001;
    DisplayRecord *second = [DisplayRecord new]; second.displayID = 100002;
    ContentRecord *content = [ContentRecord new]; content.displays = @[first, second];
    check(@"explicit_display_exact_identity", (id)[capture selectDisplayFromContent:(id)content sourceId:@"100002"] == second);
    check(@"missing_explicit_display_fails_closed", [capture selectDisplayFromContent:(id)content sourceId:@"100003"] == nil);
    check(@"implicit_display_keeps_default_selection", [capture selectDisplayFromContent:(id)content sourceId:nil] != nil);
    WindowRecord *window = [WindowRecord new]; window.windowID = 200001; content.windows = @[window];
    check(@"explicit_window_exact_identity", (id)[capture selectWindowFromContent:(id)content sourceId:@"200001"] == window);
    check(@"missing_window_never_widens_to_display", [capture selectWindowFromContent:(id)content sourceId:@"200002"] == nil);
    check(@"portrait_even_geometry", CGSizeEqualToSize([capture outputSizeForWidth:1081 height:1921 maximumResolution:1280], CGSizeMake(720, 1280)));
    check(@"ultrawide_even_geometry", CGSizeEqualToSize([capture outputSizeForWidth:3440 height:1440 maximumResolution:1920], CGSizeMake(1920, 802)));
    check(@"retina_pixel_geometry_cap", CGSizeEqualToSize([capture outputSizeForWidth:3024 height:1964 maximumResolution:1920], CGSizeMake(1920, 1246)));
    check(@"invalid_source_geometry_rejected", CGSizeEqualToSize([capture outputSizeForWidth:NAN height:1964 maximumResolution:1920], CGSizeZero));

    deliver(capture, [NSObject new], CMTimeMake(1, 1), @(SCFrameStatusComplete));
    check(@"never_started_callback_rejected", sink.frames.count == 0);
    [sink.frames removeAllObjects];
    __block BOOL stopped = NO;
    [capture stopCaptureWithCompletion:^{ stopped = YES; }];
    deliver(capture, [NSObject new], CMTimeMake(2, 1), @(SCFrameStatusComplete));
    dispatch_sync([capture valueForKey:@"audioQueue"], ^{});
    check(@"stopped_callback_rejected", stopped && sink.frames.count == 0);

    NSObject *identity;
    sink = [FrameSink new]; capture = active(sink, &identity);
    deliver(capture, identity, CMTimeMake(3, 1), @(SCFrameStatusComplete));
    RTCVideoFrame *frame = sink.frames.lastObject;
    CVPixelBufferRef retained = [(RTCCVPixelBuffer *)frame.buffer pixelBuffer];
    check(@"complete_sample_keeps_dimensions_timestamp_and_buffer_lifetime",
        sink.frames.count == 1 && frame.width == 64 && frame.height == 32 && frame.timeStampNs == 3000000000LL
        && frame.rotation == RTCVideoRotation_0 && retained != NULL
        && CVPixelBufferGetBytesPerRowOfPlane(retained, 0) >= 64
        && CVPixelBufferGetPixelFormatType(retained) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    [sink.frames removeAllObjects];
    deliver(capture, [NSObject new], CMTimeMake(4, 1), @(SCFrameStatusComplete));
    check(@"foreign_stream_callback_rejected", sink.frames.count == 0);

    NSArray *statuses = @[@(SCFrameStatusIdle), @(SCFrameStatusBlank), @(SCFrameStatusSuspended), @(SCFrameStatusStarted), @(SCFrameStatusStopped)];
    NSArray *names = @[@"idle_sample_not_counted_as_video", @"blank_sample_not_counted_as_video", @"suspended_sample_not_counted_as_video", @"started_marker_not_counted_as_complete_video", @"stopped_marker_not_counted_as_video"];
    for (NSUInteger i = 0; i < statuses.count; i++) {
      sink = [FrameSink new]; capture = active(sink, &identity);
      deliver(capture, identity, CMTimeMake(5, 1), statuses[i]);
      check(names[i], sink.frames.count == 0);
    }
    sink = [FrameSink new]; capture = active(sink, &identity);
    deliver(capture, identity, CMTimeMake(5, 1), nil);
    check(@"missing_frame_status_rejected", sink.frames.count == 0);
    sink = [FrameSink new]; capture = active(sink, &identity);
    CMSampleBufferRef invalid = sample(CMTimeMake(5, 1), @(SCFrameStatusComplete));
    CMSampleBufferInvalidate(invalid);
    [capture stream:(SCStream *)identity didOutputSampleBuffer:invalid ofType:SCStreamOutputTypeScreen];
    CFRelease(invalid);
    check(@"invalidated_sample_rejected", sink.frames.count == 0);
    sink = [FrameSink new]; capture = active(sink, &identity);
    deliver(capture, identity, kCMTimeInvalid, @(SCFrameStatusComplete));
    check(@"invalid_pts_rejected", sink.frames.count == 0);
    sink = [FrameSink new]; capture = active(sink, &identity);
    deliver(capture, identity, CMTimeMake(6, 1), @(SCFrameStatusComplete));
    deliver(capture, identity, CMTimeMake(6, 1), @(SCFrameStatusComplete));
    deliver(capture, identity, CMTimeMake(5, 1), @(SCFrameStatusComplete));
    check(@"duplicate_and_reversed_pts_rejected", sink.frames.count == 1);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"cases": cases} options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [[cases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == 'FAIL'"]] count] ? 1 : 0;
  }
}
