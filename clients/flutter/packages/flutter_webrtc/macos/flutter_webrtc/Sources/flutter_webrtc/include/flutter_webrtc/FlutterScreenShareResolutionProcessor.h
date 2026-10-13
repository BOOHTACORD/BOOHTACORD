#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

#import "VideoProcessingAdapter.h"

NS_ASSUME_NONNULL_BEGIN
@class FlutterScreenCaptureDiagnostics;

@interface FlutterScreenShareResolutionProcessor : NSObject <ExternalVideoProcessingDelegate>
@property(nonatomic, strong, nullable) FlutterScreenCaptureDiagnostics *captureDiagnostics;
@property(nonatomic) NSUInteger diagnosticsGeneration;

- (instancetype)initWithMaximumResolution:(NSInteger)maximumResolution;

@end

NS_ASSUME_NONNULL_END
