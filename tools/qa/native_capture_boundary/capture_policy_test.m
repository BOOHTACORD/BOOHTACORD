// Tests the production availability policy, including the macOS 12 fallback.
#import <Foundation/Foundation.h>
#import "FlutterScreenCapturePolicy.h"

int main(void) {
  @autoreleasepool {
    NSCAssert(FlutterScreenCaptureKitWindowRequested(@"screen_capture_kit", YES),
              @"supported window uses ScreenCaptureKit");
    NSCAssert(!FlutterScreenCaptureKitWindowRequested(@"screen_capture_kit", NO),
              @"unsupported macOS keeps the legacy window capturer");
    NSCAssert(!FlutterScreenCaptureKitWindowRequested(@"baseline", YES),
              @"explicit baseline keeps the legacy window capturer");
    NSCAssert(!FlutterScreenCaptureKitWindowRequested(@"baseline", NO),
              @"baseline remains available on older macOS");
    puts("PASS: supported default, unsupported fallback, baseline override (4 cases)");
  }
  return 0;
}
