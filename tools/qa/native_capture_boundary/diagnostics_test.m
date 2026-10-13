#import <Foundation/Foundation.h>
#import "FlutterScreenCaptureDiagnostics.h"

int main(void) {
  @autoreleasepool {
    NSMutableArray *cases = [NSMutableArray new];
    void (^check)(NSString *, BOOL) = ^(NSString *name, BOOL passed) {
      [cases addObject:@{@"name": name, @"status": passed ? @"PASS" : @"FAIL"}];
    };
    FlutterScreenCaptureDiagnostics *d = [FlutterScreenCaptureDiagnostics new];
    NSUInteger generation = [d beginWithEngine:@"screen_capture_kit" sourceClass:@"window"];
    check(@"begin_pending_with_unknown_config", ![d.snapshot[@"config_confirmed"] boolValue]
        && d.snapshot[@"configured_width"] == NSNull.null);
    check(@"unmeasured_legacy_queue_is_unknown", d.snapshot[@"queue_depth"] == NSNull.null);
    [d queueDepth:1 inFlight:2 ageNs:12000000 generation:generation];
    [d queueDepth:0 inFlight:1 ageNs:4000000 generation:generation];
    check(@"queue_peak_and_age_are_numeric_and_bounded", [d.snapshot[@"peak_queue_depth"] integerValue] == 1
        && [d.snapshot[@"peak_in_flight"] integerValue] == 2
        && [d.snapshot[@"maximum_queue_age_ms"] doubleValue] == 12);
    [d confirmWidth:1920 height:1080 maxFPS:60 generation:generation];
    check(@"start_ack_alone_does_not_confirm", ![d.snapshot[@"config_confirmed"] boolValue]);
    [d acceptWidth:1920 height:1080 pixelFormat:111 rotation:0 generation:generation];
    check(@"valid_frame_and_start_ack_confirm_config", [d.snapshot[@"config_confirmed"] boolValue]
        && [d.snapshot[@"configured_width"] integerValue] == 1920);
    [d deliverWidth:1280 height:720 pixelFormat:222 rotation:0 processingNs:2000000 generation:generation];
    check(@"raw_and_processed_dimensions_separate", [d.snapshot[@"source_width"] integerValue] == 1920
        && [d.snapshot[@"actual_width"] integerValue] == 1280
        && [d.snapshot[@"accepted_frames"] integerValue] == 1
        && [d.snapshot[@"postprocessed_frames"] integerValue] == 1);
    check(@"frame_age_uses_native_monotonic_clock", [d.snapshot[@"frame_age_ms"] isKindOfClass:NSNumber.class]
        && [d.snapshot[@"frame_age_ms"] doubleValue] >= 0);
    for (NSUInteger i = 0; i < 400; i++) {
      [d deliverWidth:1920 height:1080 pixelFormat:222 rotation:0 processingNs:i*1000000 generation:generation];
    }
    check(@"processing_sample_storage_bounded", [d.snapshot[@"processing_sample_count"] integerValue] == 256
        && [d.snapshot[@"processing_p95_ms"] doubleValue] <= 399);
    [d dropReason:FlutterCaptureDropIdle generation:generation];
    check(@"idle_does_not_fabricate_accepted_frames", [d.snapshot[@"accepted_frames"] integerValue] == 1
        && [d.snapshot[@"config_confirmed"] boolValue]
        && [d.snapshot[@"drop_reasons"][@"idle"] integerValue] == 1);
    [d confirmWidth:1280 height:720 maxFPS:30 generation:generation];
    check(@"resize_ack_does_not_reuse_old_frame_confirmation", ![d.snapshot[@"config_confirmed"] boolValue]);
    [d acceptWidth:1280 height:720 pixelFormat:111 rotation:0 generation:generation];
    check(@"resize_config_confirms_only_matching_new_frame", [d.snapshot[@"config_confirmed"] boolValue]);
    [d stop];
    [d acceptWidth:999 height:999 pixelFormat:111 rotation:0 generation:generation];
    [d deliverWidth:999 height:999 pixelFormat:111 rotation:0 processingNs:1 generation:generation];
    check(@"stopped_generation_rejects_metrics", [d.snapshot[@"status"] isEqualToString:@"stopped"]
        && ![d.snapshot[@"config_confirmed"] boolValue]
        && [d.snapshot[@"actual_width"] integerValue] == 1920);
    NSUInteger next = [d beginWithEngine:@"rtc_desktop_capturer" sourceClass:@"display"];
    [d confirmWidth:2 height:2 maxFPS:1 generation:generation];
    check(@"new_generation_clears_old_confirmation_and_counts", next != generation
        && [d.snapshot[@"accepted_frames"] integerValue] == 0
        && d.snapshot[@"actual_width"] == NSNull.null
        && ![d.snapshot[@"config_confirmed"] boolValue]);
    [d failWithReason:@"start_failed" generation:next];
    check(@"failure_has_bounded_reason_and_no_confirmation", [d.snapshot[@"status"] isEqualToString:@"error"]
        && [d.snapshot[@"error_reason"] isEqualToString:@"start_failed"]
        && ![d.snapshot[@"config_confirmed"] boolValue]);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"cases": cases} options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [[cases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == 'FAIL'"]] count] ? 1 : 0;
  }
}
