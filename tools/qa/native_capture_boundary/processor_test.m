// Actual resolution processor with a controlled conversion-helper dependency.
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import "FlutterRTCFrameCapturer.h"
#import "FlutterScreenShareResolutionProcessor.h"

static NSUInteger conversionCalls;
static BOOL conversionFails;
@interface UnconvertibleBuffer : NSObject <RTCVideoFrameBuffer>
@end
@implementation UnconvertibleBuffer
- (int)width { return 801; }
- (int)height { return 601; }
- (id<RTCI420Buffer>)toI420 { return nil; }
@end

// This helper spy returns a retained native buffer or an injected allocation /
// conversion failure. It does not test the real I420 conversion implementation.
@implementation FlutterRTCFrameCapturer
- (instancetype)initWithTrack:(RTCVideoTrack *)track toPath:(NSString *)path result:(FlutterResult)result {
  return [super init];
}
+ (CVPixelBufferRef)convertToCVPixelBuffer:(RTCVideoFrame *)frame {
  conversionCalls++;
  if (conversionFails) return NULL;
  return CVPixelBufferRetain([(RTCCVPixelBuffer *)frame.buffer pixelBuffer]);
}
- (void)setSize:(CGSize)size {}
- (void)renderFrame:(RTCVideoFrame *)frame {}
@end

static RTCVideoFrame *frame(size_t width, size_t height, RTCVideoRotation rotation) {
  CVPixelBufferRef pixel = NULL;
  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
      kCVPixelFormatType_32BGRA,
      (__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &pixel);
  NSCAssert(status == kCVReturnSuccess && pixel != NULL, @"synthetic allocation failed");
  CVPixelBufferLockBaseAddress(pixel, 0);
  memset(CVPixelBufferGetBaseAddress(pixel), 0, CVPixelBufferGetBytesPerRow(pixel) * height);
  CVPixelBufferUnlockBaseAddress(pixel, 0);
  RTCCVPixelBuffer *buffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixel];
  CVPixelBufferRelease(pixel);
  return [[RTCVideoFrame alloc] initWithBuffer:buffer rotation:rotation timeStampNs:7000000000LL];
}

int main(void) {
  @autoreleasepool {
    NSMutableArray *cases = [NSMutableArray new];
    void (^check)(NSString *, BOOL) = ^(NSString *name, BOOL passed) {
      [cases addObject:@{@"name": name, @"status": passed ? @"PASS" : @"FAIL"}];
    };
    FlutterScreenShareResolutionProcessor *processor = [[FlutterScreenShareResolutionProcessor alloc] initWithMaximumResolution:128];
    RTCVideoFrame *input = frame(64, 32, RTCVideoRotation_0);
    RTCVideoFrame *output = [processor onFrame:input];
    check(@"in_profile_frame_is_identity_and_skips_conversion", output == input && conversionCalls == 0);
    input = frame(128, 256, RTCVideoRotation_90);
    output = [processor onFrame:input];
    check(@"compatible_native_pixel_buffer_skips_generic_conversion", conversionCalls == 0);
    check(@"portrait_scale_keeps_even_geometry_rotation_pts", output.width == 64 && output.height == 128
        && output.rotation == RTCVideoRotation_90 && output.timeStampNs == input.timeStampNs);
    processor = [[FlutterScreenShareResolutionProcessor alloc] initWithMaximumResolution:720];
    input = frame(801, 601, RTCVideoRotation_0);
    output = [processor onFrame:input];
    check(@"odd_source_scale_keeps_aspect_and_even_cap", output.width == 720 && output.height == 540);
    RTCVideoFrame *i420 = [[RTCVideoFrame alloc] initWithBuffer:[input.buffer toI420] rotation:RTCVideoRotation_0 timeStampNs:7000000000LL];
    RTCVideoFrame *scaledI420 = [processor onFrame:i420];
    check(@"real_i420_fallback_scales_without_bgra_roundtrip", scaledI420.width == 720 && scaledI420.height == 540
        && ![scaledI420.buffer isKindOfClass:RTCCVPixelBuffer.class]);
    FlutterScreenShareResolutionProcessor *poolProcessor = [[FlutterScreenShareResolutionProcessor alloc] initWithMaximumResolution:128];
    NSMutableArray *held = [NSMutableArray new];
    RTCVideoFrame *large = frame(256, 128, RTCVideoRotation_0);
    for (NSUInteger i = 0; i < 4; i++) { RTCVideoFrame *next = [poolProcessor onFrame:large]; if (next) [held addObject:next]; }
    check(@"pool_exhaustion_drops_instead_of_oversized_output", held.count == 4 && [poolProcessor onFrame:large] == nil);
    [held removeAllObjects];
    check(@"released_pool_buffers_can_be_reused", [poolProcessor onFrame:large] != nil);
    CGColorSpaceRef p3 = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CVPixelBufferRef p3Pixel = ((RTCCVPixelBuffer *)large.buffer).pixelBuffer;
    CVBufferSetAttachment(p3Pixel, kCVImageBufferCGColorSpaceKey, p3, kCVAttachmentMode_ShouldPropagate);
    NSDictionary *oldAperture = @{(id)kCVImageBufferCleanApertureWidthKey: @256,
      (id)kCVImageBufferCleanApertureHeightKey: @128,
      (id)kCVImageBufferCleanApertureHorizontalOffsetKey: @0,
      (id)kCVImageBufferCleanApertureVerticalOffsetKey: @0};
    NSDictionary *oldDimensions = @{(id)kCVImageBufferDisplayWidthKey: @256, (id)kCVImageBufferDisplayHeightKey: @128};
    CVBufferSetAttachment(p3Pixel, kCVImageBufferCleanApertureKey, (__bridge CFDictionaryRef)oldAperture, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(p3Pixel, kCVImageBufferDisplayDimensionsKey, (__bridge CFDictionaryRef)oldDimensions, kCVAttachmentMode_ShouldPropagate);
    RTCVideoFrame *colorOutput = [poolProcessor onFrame:large];
    CVPixelBufferRef resizedPixel = ((RTCCVPixelBuffer *)colorOutput.buffer).pixelBuffer;
    CGColorSpaceRef labeled = (CGColorSpaceRef)CVBufferGetAttachment(resizedPixel,
        kCVImageBufferCGColorSpaceKey, NULL);
    CFStringRef label = labeled ? CGColorSpaceCopyName(labeled) : NULL;
    check(@"rendered_srgb_pixels_are_labeled_srgb", label && CFEqual(label, kCGColorSpaceSRGB));
    NSDictionary *aperture = (__bridge NSDictionary *)CVBufferGetAttachment(resizedPixel, kCVImageBufferCleanApertureKey, NULL);
    NSDictionary *dimensions = (__bridge NSDictionary *)CVBufferGetAttachment(resizedPixel, kCVImageBufferDisplayDimensionsKey, NULL);
    check(@"resized_buffer_has_current_aperture_and_display_dimensions",
        [aperture[(id)kCVImageBufferCleanApertureWidthKey] integerValue] == 128
        && [aperture[(id)kCVImageBufferCleanApertureHeightKey] integerValue] == 64
        && [dimensions[(id)kCVImageBufferDisplayWidthKey] integerValue] == 128
        && [dimensions[(id)kCVImageBufferDisplayHeightKey] integerValue] == 64);
    RTCVideoFrame *identity = [[[FlutterScreenShareResolutionProcessor alloc] initWithMaximumResolution:256] onFrame:large];
    check(@"no_resize_keeps_original_buffer_and_source_attachments", identity == large
        && CFEqual(CVBufferGetAttachment(((RTCCVPixelBuffer *)identity.buffer).pixelBuffer, kCVImageBufferCGColorSpaceKey, NULL), p3));
    if (label) CFRelease(label); CGColorSpaceRelease(p3);
    conversionFails = YES;
    input = [[RTCVideoFrame alloc] initWithBuffer:[UnconvertibleBuffer new] rotation:RTCVideoRotation_0 timeStampNs:7000000000LL];
    output = [processor onFrame:input];
    check(@"conversion_failure_cannot_forward_oversized_frame", output == nil || MAX(output.width, output.height) <= 720);
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"cases": cases} options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(json.bytes, 1, json.length, stdout); fputc('\n', stdout);
    return [[cases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == 'FAIL'"]] count] ? 1 : 0;
  }
}
