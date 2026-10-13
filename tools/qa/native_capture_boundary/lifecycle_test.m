#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import "FlutterScreenCaptureKitCapturer.h"
#import "FlutterScreenCaptureDiagnostics.h"

@interface FlutterScreenCaptureKitCapturer (LifecycleTests)
- (void)finishStart:(NSError *)error generation:(NSUInteger)generation;
- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sample ofType:(SCStreamOutputType)type;
@end
@interface StreamIdentity : NSObject
@property(nonatomic) NSUInteger stops;
@end
@implementation StreamIdentity
- (void)stopCaptureWithCompletionHandler:(void (^)(NSError *))completion { self.stops++; completion(nil); }
@end
@interface Sink : NSObject <RTCVideoCapturerDelegate>
@property(nonatomic) NSUInteger frames;
@property(nonatomic) int64_t lastTimestamp;
@end
@implementation Sink
- (void)capturer:(RTCVideoCapturer *)capture didCaptureVideoFrame:(RTCVideoFrame *)frame { self.frames++; self.lastTimestamp = frame.timeStampNs; }
@end
@interface BlockedSink : Sink
@property(nonatomic, strong) dispatch_semaphore_t entered;
@property(nonatomic, strong) dispatch_semaphore_t releaseFrame;
@end
@implementation BlockedSink
- (void)capturer:(RTCVideoCapturer *)capture didCaptureVideoFrame:(RTCVideoFrame *)frame {
  [super capturer:capture didCaptureVideoFrame:frame];
  if (self.frames == 1) { dispatch_semaphore_signal(self.entered); dispatch_semaphore_wait(self.releaseFrame, DISPATCH_TIME_FOREVER); }
}
@end
@interface AudioSink : NSObject
@property(nonatomic) NSUInteger samples;
@end
@implementation AudioSink
- (void)appendSampleBuffer:(CMSampleBufferRef)sample { self.samples++; }
- (void)stop {}
@end
static uint64_t virtualNow;
@interface VirtualClockCapture : FlutterScreenCaptureKitCapturer
@end
@implementation VirtualClockCapture
- (uint64_t)monotonicTimeNs { return virtualNow; }
@end
@interface VirtualClockDiagnostics : FlutterScreenCaptureDiagnostics
@end
@implementation VirtualClockDiagnostics
+ (uint64_t)monotonicTimeNs { return virtualNow; }
@end

static CMSampleBufferRef validSample(CMTime pts) {
  CVPixelBufferRef pixel; CMVideoFormatDescriptionRef format; CMSampleBufferRef sample;
  NSCAssert(CVPixelBufferCreate(NULL, 64, 32, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, &pixel) == 0, @"pixel");
  NSCAssert(CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixel, &format) == 0, @"format");
  CMSampleTimingInfo timing = {CMTimeMake(1, 30), pts, kCMTimeInvalid};
  NSCAssert(CMSampleBufferCreateReadyWithImageBuffer(NULL, pixel, format, &timing, &sample) == 0, @"sample");
  CFMutableDictionaryRef info = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sample, YES), 0);
  CFDictionarySetValue(info, (__bridge CFStringRef)SCStreamFrameInfoStatus, (__bridge CFNumberRef)@(SCFrameStatusComplete));
  CFRelease(format); CFRelease(pixel); return sample;
}
static void flush(FlutterScreenCaptureKitCapturer *capture) {
  dispatch_sync([capture valueForKey:@"processingQueue"], ^{});
  dispatch_sync([capture valueForKey:@"audioQueue"], ^{});
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
static FlutterScreenCaptureKitCapturer *session(Sink *sink, StreamIdentity *stream, void (^ready)(NSError *)) {
  FlutterScreenCaptureKitCapturer *capture = [[FlutterScreenCaptureKitCapturer alloc] initWithDelegate:sink];
  [capture setValue:@YES forKey:@"active"]; [capture setValue:@7 forKey:@"generation"];
  [capture setValue:stream forKey:@"stream"]; [capture setValue:ready forKey:@"startCallback"];
  return capture;
}
int main(void) {
  @autoreleasepool {
    NSMutableArray *cases = [NSMutableArray new];
    void (^check)(NSString *, BOOL) = ^(NSString *name, BOOL pass) {
      [cases addObject:@{@"name": name, @"status": pass ? @"PASS" : @"FAIL"}];
    };
    __block NSUInteger calls = 0; __block BOOL failed = NO;
    Sink *sink = [Sink new]; StreamIdentity *stream = [StreamIdentity new];
    FlutterScreenCaptureKitCapturer *capture = session(sink, stream, ^(NSError *e) { calls++; failed = e != nil; });
    [capture setValue:@YES forKey:@"startCompleted"];
    [capture finishStart:nil generation:7]; flush(capture);
    check(@"start_ack_without_valid_frame_remains_pending", calls == 0);
    CMSampleBufferRef sample = validSample(CMTimeMake(1, 1));
    [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeScreen]; flush(capture);
    check(@"start_ack_and_first_delivered_frame_complete_once", calls == 1 && !failed && sink.frames == 1);
    [capture finishStart:nil generation:7]; flush(capture);
    check(@"duplicate_ready_completion_is_ignored", calls == 1);
    [capture stopCaptureWithCompletion:^{}]; flush(capture);

    calls = 0; failed = NO; sink = [Sink new]; stream = [StreamIdentity new];
    capture = session(sink, stream, ^(NSError *e) { calls++; failed = e != nil; });
    [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeScreen]; flush(capture);
    check(@"valid_frame_without_start_ack_remains_pending", calls == 0 && sink.frames == 1);
    [capture setValue:@YES forKey:@"startCompleted"]; [capture finishStart:nil generation:7]; flush(capture);
    check(@"ack_after_first_frame_completes_once", calls == 1 && !failed);
    [capture stopCaptureWithCompletion:^{}]; flush(capture);

    calls = 0; failed = NO; sink = [Sink new]; stream = [StreamIdentity new];
    capture = session(sink, stream, ^(NSError *e) { calls++; failed = e != nil; });
    [capture stopCaptureWithCompletion:^{}]; flush(capture);
    [capture finishStart:nil generation:7];
    [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeScreen]; flush(capture);
    check(@"pending_stop_invalidates_late_ready_and_frames", calls == 1 && failed && sink.frames == 0 && stream.stops == 1);

    calls = 0; failed = NO; sink = [Sink new]; stream = [StreamIdentity new];
    capture = session(sink, stream, ^(NSError *e) { calls++; failed = e != nil; });
    [capture setValue:@YES forKey:@"startCompleted"]; [capture setValue:@YES forKey:@"firstFrameDelivered"];
    [capture finishStart:nil generation:7]; // Main-queue completion is deliberately still pending.
    [capture stopCaptureWithCompletion:^{}]; flush(capture);
    check(@"queued_ready_cannot_revive_stopped_generation", calls == 1 && failed);

    BlockedSink *blocked = [BlockedSink new]; blocked.entered = dispatch_semaphore_create(0); blocked.releaseFrame = dispatch_semaphore_create(0);
    stream = [StreamIdentity new]; capture = session(blocked, stream, ^(NSError *e) {});
    FlutterScreenCaptureDiagnostics *d = [FlutterScreenCaptureDiagnostics new];
    NSUInteger token = [d beginWithEngine:@"screen_capture_kit" sourceClass:@"window"];
    capture.captureDiagnostics = d; capture.diagnosticsGeneration = token;
    [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeScreen];
    BOOL entered = dispatch_semaphore_wait(blocked.entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0;
    for (NSInteger i = 2; i <= 6; i++) {
      CMSampleBufferRef next = validSample(CMTimeMake(i, 1));
      [capture stream:(SCStream *)stream didOutputSampleBuffer:next ofType:SCStreamOutputTypeScreen]; CFRelease(next);
    }
    check(@"video_pressure_keeps_one_pending_and_one_processing", entered
        && [d.snapshot[@"peak_queue_depth"] integerValue] == 1 && [d.snapshot[@"peak_in_flight"] integerValue] == 2
        && [d.snapshot[@"drop_reasons"][@"queue"] integerValue] == 4);
    // A routing spy proves queue isolation, not PCM decoding or physical audio.
    AudioSink *audio = [AudioSink new]; capture.screenAudioCapturer = (id)audio;
    dispatch_semaphore_t audioDelivered = dispatch_semaphore_create(0);
    dispatch_async([capture valueForKey:@"audioQueue"], ^{
      [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeAudio];
      dispatch_semaphore_signal(audioDelivered);
    });
    BOOL audioReady = dispatch_semaphore_wait(audioDelivered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0;
    check(@"audio_dispatch_is_not_blocked_by_video_pressure", audioReady && audio.samples == 1);
    dispatch_semaphore_signal(blocked.releaseFrame); flush(capture);
    check(@"video_pressure_delivers_latest_pending_timestamp", blocked.frames == 2 && blocked.lastTimestamp == 6000000000LL);
    [capture stopCaptureWithCompletion:^{}]; flush(capture);
    // Simulate a long suspended gap while one sample waits. No physical sleep.
    virtualNow = 1000000000LL;
    sink = [Sink new]; stream = [StreamIdentity new];
    capture = [[VirtualClockCapture alloc] initWithDelegate:sink];
    [capture setValue:@YES forKey:@"active"]; [capture setValue:@7 forKey:@"generation"];
    [capture setValue:stream forKey:@"stream"];
    d = [VirtualClockDiagnostics new]; token = [d beginWithEngine:@"screen_capture_kit" sourceClass:@"window"];
    capture.captureDiagnostics = d; capture.diagnosticsGeneration = token;
    dispatch_semaphore_t queueHeld = dispatch_semaphore_create(0), queueRelease = dispatch_semaphore_create(0);
    dispatch_async([capture valueForKey:@"processingQueue"], ^{
      dispatch_semaphore_signal(queueHeld); dispatch_semaphore_wait(queueRelease, DISPATCH_TIME_FOREVER);
    });
    dispatch_semaphore_wait(queueHeld, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    [capture stream:(SCStream *)stream didOutputSampleBuffer:sample ofType:SCStreamOutputTypeScreen];
    virtualNow += 10 * NSEC_PER_SEC;
    dispatch_semaphore_signal(queueRelease); flush(capture);
    check(@"suspended_clock_gap_drops_queued_frame_and_ages_snapshot", sink.frames == 0
        && [d.snapshot[@"drop_reasons"][@"queue"] integerValue] == 1
        && [d.snapshot[@"frame_age_ms"] doubleValue] == 10000);
    [capture stopCaptureWithCompletion:^{}]; flush(capture);
    CFRelease(sample);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"cases": cases} options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [[cases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == 'FAIL'"]] count] ? 1 : 0;
  }
}
