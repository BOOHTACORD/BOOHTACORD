// Executes the actual getDisplayMedia category with injected factory/enumeration.
#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <objc/runtime.h>
#import "FlutterRTCDesktopCapturer.h"
#import "ScreenAudioTrackCapturer.h"

static NSMutableArray *enumerations;
static __weak NSObject *lastSource;
@interface SCShareableContent (StartupTest)
+ (void)testContent:(void (^)(SCShareableContent *, NSError *))handler;
@end
@implementation SCShareableContent (StartupTest)
+ (void)testContent:(void (^)(SCShareableContent *, NSError *))handler { [enumerations addObject:[handler copy]]; }
@end
@interface Factory : NSObject
@end
@implementation Factory
- (id)mediaStreamWithStreamId:(NSString *)identifier { return nil; }
- (id)videoSourceForScreenCast:(BOOL)screen { NSObject *source = [NSObject new]; lastSource = source; return source; }
@end

// Only dependencies are fakes. Capture setup, callbacks, stop and registry
// ownership execute the vendored DesktopCapturer and SCK implementations.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation FlutterWebRTCPlugin
@synthesize peerConnectionFactory, localTracks, localStreams, videoCapturerStopHandlers;
@end
#pragma clang diagnostic pop
@implementation FlutterError
+ (instancetype)errorWithCode:(NSString *)code message:(NSString *)message details:(id)details { return [self new]; }
@end
@implementation FlutterScreenAudioTrackCapturer
- (instancetype)initWithFactory:(RTCPeerConnectionFactory *)factory { return [super init]; }
- (RTCAudioTrack *)audioTrack { return nil; }
- (void)stop {}
- (void)appendSampleBuffer:(CMSampleBufferRef)sample {}
- (void)appendPCMData:(NSData *)data sampleRate:(int)rate channels:(size_t)channels frames:(size_t)frames {}
@end
void postEvent(FlutterEventSink sink, id event) {}
@interface AudioManager : NSObject
@end
@implementation AudioManager
@end

int main(void) {
  @autoreleasepool {
    enumerations = [NSMutableArray new];
    Method actual = class_getClassMethod(SCShareableContent.class, @selector(getShareableContentWithCompletionHandler:));
    Method replacement = class_getClassMethod(SCShareableContent.class, @selector(testContent:));
    method_exchangeImplementations(actual, replacement);
    NSMutableArray *cases = [NSMutableArray new];
    for (NSNumber *audio in @[@NO, @YES]) {
      FlutterWebRTCPlugin *plugin = [FlutterWebRTCPlugin new];
      plugin.peerConnectionFactory = (id)[Factory new];
      plugin.localTracks = [NSMutableDictionary new]; plugin.localStreams = [NSMutableDictionary new];
      plugin.videoCapturerStopHandlers = [NSMutableDictionary new];
      __block BOOL completed = NO, failed = NO;
      @autoreleasepool {
        [plugin getDisplayMedia:@{@"audio": audio, @"video": @YES} result:^(id result) {
          completed = YES; failed = [result isKindOfClass:FlutterError.class];
        }];
        NSCAssert(enumerations.count == 1, @"expected injected content request");
        @autoreleasepool {
          void (^handler)(SCShareableContent *, NSError *) = enumerations.firstObject;
          [enumerations removeObjectAtIndex:0];
          handler(nil, [NSError errorWithDomain:@"synthetic" code:1 userInfo:nil]);
        }
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
        while (!completed && deadline.timeIntervalSinceNow > 0)
          [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
      }
      BOOL clean = completed && failed && plugin.videoCapturerStopHandlers.count == 0
          && plugin.localTracks.count == 0 && plugin.localStreams.count == 0 && lastSource == nil;
      [cases addObject:@{@"name": audio.boolValue ? @"audio_start_failure_releases_unreturned_capture" : @"video_start_failure_releases_unreturned_capture",
                        @"status": clean ? @"PASS" : @"FAIL",
                        @"stop_handler_count": @(plugin.videoCapturerStopHandlers.count),
                        @"source_released": @(lastSource == nil)}];
    }
    method_exchangeImplementations(actual, replacement);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"cases": cases} options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [[cases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == 'FAIL'"]] count] ? 1 : 0;
  }
}
