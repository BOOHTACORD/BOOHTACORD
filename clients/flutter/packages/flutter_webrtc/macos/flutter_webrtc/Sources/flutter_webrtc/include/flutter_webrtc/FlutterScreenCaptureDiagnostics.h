#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FlutterCaptureDropReason) {
  FlutterCaptureDropIdle, FlutterCaptureDropIncomplete, FlutterCaptureDropInvalid,
  FlutterCaptureDropTimestamp, FlutterCaptureDropStale, FlutterCaptureDropProcessing,
  FlutterCaptureDropQueue,
};
typedef NS_ENUM(NSUInteger, FlutterCaptureOperation) {
  FlutterCaptureNativeResize, FlutterCaptureI420Scale, FlutterCapturePoolCreated,
  FlutterCapturePoolAcquire, FlutterCapturePoolBufferFirstSeen, FlutterCaptureProcessingFailure,
  FlutterCapturePassThrough,
};

/// Session-owned bounded numeric counters. Serialization happens only on query.
@interface FlutterScreenCaptureDiagnostics : NSObject
+ (uint64_t)monotonicTimeNs;
- (NSUInteger)beginWithEngine:(NSString *)engine sourceClass:(NSString *)sourceClass;
- (void)confirmWidth:(NSInteger)width height:(NSInteger)height maxFPS:(NSInteger)fps generation:(NSUInteger)generation;
- (void)acceptWidth:(NSInteger)width height:(NSInteger)height pixelFormat:(uint32_t)format rotation:(NSInteger)rotation generation:(NSUInteger)generation;
- (void)deliverWidth:(NSInteger)width height:(NSInteger)height pixelFormat:(uint32_t)format rotation:(NSInteger)rotation processingNs:(uint64_t)duration generation:(NSUInteger)generation;
- (void)dropReason:(FlutterCaptureDropReason)reason generation:(NSUInteger)generation;
- (void)operation:(FlutterCaptureOperation)operation generation:(NSUInteger)generation;
- (void)queueDepth:(NSUInteger)depth inFlight:(NSUInteger)inFlight ageNs:(uint64_t)age generation:(NSUInteger)generation;
- (void)failWithReason:(NSString *)reason generation:(NSUInteger)generation;
- (void)stop;
- (NSDictionary *)snapshot;
@end
