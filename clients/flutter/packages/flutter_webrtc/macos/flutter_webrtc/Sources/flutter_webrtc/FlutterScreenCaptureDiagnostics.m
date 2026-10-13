#import "FlutterScreenCaptureDiagnostics.h"
#import <mach/mach_time.h>
#import <os/lock.h>

enum { kCaptureSampleCapacity = 256 };
static int compareNs(const void *a, const void *b) {
  uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
  return (x > y) - (x < y);
}

@implementation FlutterScreenCaptureDiagnostics {
  os_unfair_lock _lock;
  NSUInteger _generation;
  NSString *_engine, *_sourceClass, *_status, *_errorReason;
  BOOL _startConfirmed, _configConfirmed;
  NSInteger _configuredWidth, _configuredHeight, _configuredFPS;
  NSInteger _sourceWidth, _sourceHeight, _actualWidth, _actualHeight, _rotation;
  uint32_t _sourceFormat, _actualFormat;
  uint64_t _accepted, _delivered, _drops[7], _lastValidNs;
  uint64_t _processing[kCaptureSampleCapacity];
  NSUInteger _sampleCount, _sampleIndex;
  uint64_t _operations[7], _queueAgeNs, _maximumQueueAgeNs;
  NSUInteger _queueDepth, _peakQueueDepth, _inFlight, _peakInFlight;
  BOOL _queueMeasured;
}
+ (uint64_t)monotonicTimeNs {
  static mach_timebase_info_data_t timebase;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ mach_timebase_info(&timebase); });
  uint64_t ticks = mach_continuous_time(); // Includes suspended time; stale frames stay stale after wake.
  return (uint64_t)(((__uint128_t)ticks * timebase.numer) / timebase.denom);
}
- (instancetype)init {
  if ((self = [super init])) { _lock = OS_UNFAIR_LOCK_INIT; _status = @"unavailable"; }
  return self;
}
- (NSUInteger)beginWithEngine:(NSString *)engine sourceClass:(NSString *)sourceClass {
  os_unfair_lock_lock(&_lock);
  _generation++;
  _engine = [engine copy]; _sourceClass = [sourceClass copy]; _status = @"pending"; _errorReason = nil;
  _startConfirmed = NO; _configConfirmed = NO;
  _configuredWidth = _configuredHeight = _configuredFPS = 0;
  _sourceWidth = _sourceHeight = _actualWidth = _actualHeight = _rotation = 0;
  _sourceFormat = _actualFormat = 0; _accepted = _delivered = _lastValidNs = 0;
  memset(_drops, 0, sizeof(_drops)); _sampleCount = _sampleIndex = 0;
  memset(_operations, 0, sizeof(_operations));
  _queueAgeNs = _maximumQueueAgeNs = _queueDepth = _peakQueueDepth = _inFlight = _peakInFlight = 0;
  _queueMeasured = NO;
  NSUInteger generation = _generation;
  os_unfair_lock_unlock(&_lock);
  return generation;
}
- (BOOL)isCurrent:(NSUInteger)generation {
  return generation == _generation && ([_status isEqualToString:@"pending"] || [_status isEqualToString:@"active"]);
}
- (void)confirmWidth:(NSInteger)width height:(NSInteger)height maxFPS:(NSInteger)fps generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation] && width > 0 && height > 0 && fps > 0) {
    _configuredWidth = width; _configuredHeight = height; _configuredFPS = fps; _startConfirmed = YES;
    _configConfirmed = _accepted > 0 && _sourceWidth == width && _sourceHeight == height;
    _status = _configConfirmed ? @"active" : @"pending";
  }
  os_unfair_lock_unlock(&_lock);
}
- (void)acceptWidth:(NSInteger)width height:(NSInteger)height pixelFormat:(uint32_t)format rotation:(NSInteger)rotation generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation] && width > 0 && height > 0) {
    _accepted++; _sourceWidth = width; _sourceHeight = height; _sourceFormat = format; _rotation = rotation;
    _lastValidNs = self.class.monotonicTimeNs;
    _configConfirmed = _startConfirmed && width == _configuredWidth && height == _configuredHeight;
    _status = _configConfirmed ? @"active" : @"pending";
  }
  os_unfair_lock_unlock(&_lock);
}
- (void)deliverWidth:(NSInteger)width height:(NSInteger)height pixelFormat:(uint32_t)format rotation:(NSInteger)rotation processingNs:(uint64_t)duration generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation] && width > 0 && height > 0) {
    _delivered++; _actualWidth = width; _actualHeight = height; _actualFormat = format; _rotation = rotation;
    _processing[_sampleIndex] = duration; _sampleIndex = (_sampleIndex + 1) % kCaptureSampleCapacity;
    _sampleCount = MIN(kCaptureSampleCapacity, _sampleCount + 1);
  }
  os_unfair_lock_unlock(&_lock);
}
- (void)dropReason:(FlutterCaptureDropReason)reason generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation] && reason <= FlutterCaptureDropQueue) _drops[reason]++;
  os_unfair_lock_unlock(&_lock);
}
- (void)operation:(FlutterCaptureOperation)operation generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation] && operation <= FlutterCapturePassThrough) _operations[operation]++;
  os_unfair_lock_unlock(&_lock);
}
- (void)queueDepth:(NSUInteger)depth inFlight:(NSUInteger)inFlight ageNs:(uint64_t)age generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation]) {
    _queueMeasured = YES;
    _queueDepth = depth; _inFlight = inFlight;
    _peakQueueDepth = MAX(_peakQueueDepth, depth); _peakInFlight = MAX(_peakInFlight, inFlight);
    _queueAgeNs = age; _maximumQueueAgeNs = MAX(_maximumQueueAgeNs, age);
  }
  os_unfair_lock_unlock(&_lock);
}
- (void)failWithReason:(NSString *)reason generation:(NSUInteger)generation {
  os_unfair_lock_lock(&_lock);
  if ([self isCurrent:generation]) {
    _status = @"error"; _configConfirmed = NO;
    NSSet *allowed = [NSSet setWithArray:@[@"start_failed", @"source_missing", @"permission_denied", @"stream_stopped", @"first_frame_timeout", @"configuration_failed"]];
    _errorReason = [allowed containsObject:reason] ? [reason copy] : @"start_failed";
  }
  os_unfair_lock_unlock(&_lock);
}
- (void)stop {
  os_unfair_lock_lock(&_lock);
  _generation++; if (![_status isEqualToString:@"error"]) _status = @"stopped";
  _configConfirmed = NO; _startConfirmed = NO;
  _queueDepth = _inFlight = 0;
  os_unfair_lock_unlock(&_lock);
}
- (NSDictionary *)snapshot {
  uint64_t values[kCaptureSampleCapacity];
  os_unfair_lock_lock(&_lock);
  NSUInteger count = _sampleCount;
  memcpy(values, _processing, count * sizeof(uint64_t));
  NSArray *reasonNames = @[@"idle", @"incomplete", @"invalid", @"timestamp", @"stale", @"processing", @"queue"];
  NSMutableDictionary *dropReasons = [NSMutableDictionary new]; uint64_t dropped = 0;
  for (NSUInteger i = 0; i < reasonNames.count; i++) { dropReasons[reasonNames[i]] = @(_drops[i]); dropped += _drops[i]; }
  uint64_t now = self.class.monotonicTimeNs;
  NSMutableDictionary *result = [@{
    @"schema_version": @1, @"status": _status, @"engine": _engine ?: (id)NSNull.null,
    @"source_class": _sourceClass ?: (id)NSNull.null, @"generation": @(_generation),
    @"config_confirmed": @(_configConfirmed),
    @"configured_width": _configConfirmed ? @(_configuredWidth) : (id)NSNull.null,
    @"configured_height": _configConfirmed ? @(_configuredHeight) : (id)NSNull.null,
    @"configured_max_fps": _configConfirmed ? @(_configuredFPS) : (id)NSNull.null,
    @"source_width": _sourceWidth ? @(_sourceWidth) : (id)NSNull.null,
    @"source_height": _sourceHeight ? @(_sourceHeight) : (id)NSNull.null,
    @"source_pixel_format": _sourceFormat ? @(_sourceFormat) : (id)NSNull.null,
    @"actual_width": _actualWidth ? @(_actualWidth) : (id)NSNull.null,
    @"actual_height": _actualHeight ? @(_actualHeight) : (id)NSNull.null,
    @"actual_pixel_format": _actualFormat ? @(_actualFormat) : (id)NSNull.null,
    @"rotation": @(_rotation), @"accepted_frames": @(_accepted), @"postprocessed_frames": @(_delivered),
    @"dropped_frames": @(dropped), @"drop_reasons": dropReasons,
    @"last_valid_frame_monotonic_ns": _lastValidNs ? @(_lastValidNs) : (id)NSNull.null,
    @"frame_age_ms": _lastValidNs ? @((double)(now - _lastValidNs) / 1000000.0) : (id)NSNull.null,
    @"frame_age_basis": @"native_monotonic_since_latest_accepted_callback",
    @"processing_sample_count": @(count), @"error_reason": _errorReason ?: (id)NSNull.null,
    @"queue_depth": _queueMeasured ? @(_queueDepth) : (id)NSNull.null,
    @"peak_queue_depth": _queueMeasured ? @(_peakQueueDepth) : (id)NSNull.null,
    @"in_flight": _queueMeasured ? @(_inFlight) : (id)NSNull.null,
    @"peak_in_flight": _queueMeasured ? @(_peakInFlight) : (id)NSNull.null,
    @"queue_age_ms": _queueMeasured ? @(_queueAgeNs / 1000000.0) : (id)NSNull.null,
    @"maximum_queue_age_ms": _queueMeasured ? @(_maximumQueueAgeNs / 1000000.0) : (id)NSNull.null,
    @"native_resize_frames": @(_operations[FlutterCaptureNativeResize]),
    @"i420_scale_frames": @(_operations[FlutterCaptureI420Scale]),
    @"buffer_pool_creations": @(_operations[FlutterCapturePoolCreated]),
    @"buffer_pool_acquisitions": @(_operations[FlutterCapturePoolAcquire]),
    @"pool_buffers_first_seen": @(_operations[FlutterCapturePoolBufferFirstSeen]),
    @"processing_failures": @(_operations[FlutterCaptureProcessingFailure]),
    @"pass_through_frames": @(_operations[FlutterCapturePassThrough]),
    @"heap_allocations": NSNull.null, @"capture_timestamp_latency_ms": NSNull.null,
    @"capture_update_mode": @"restart_required",
  } mutableCopy];
  os_unfair_lock_unlock(&_lock);
  qsort(values, count, sizeof(uint64_t), compareNs);
  result[@"processing_p50_ms"] = count ? @(values[(count - 1) / 2] / 1000000.0) : (id)NSNull.null;
  result[@"processing_p95_ms"] = count ? @(values[((count - 1) * 95) / 100] / 1000000.0) : (id)NSNull.null;
  return result;
}
@end
