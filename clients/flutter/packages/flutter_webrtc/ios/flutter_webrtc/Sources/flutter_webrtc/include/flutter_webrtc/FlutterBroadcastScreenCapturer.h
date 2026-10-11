//
//  FlutterBroadcastScreenCapturer.h
//  RCTWebRTC
//
//  Created by Alex-Dan Bumbu on 06/01/2021.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
NS_ASSUME_NONNULL_BEGIN

extern NSString* const kRTCScreensharingSocketFD;
extern NSString* const kRTCAppGroupIdentifier;
extern NSString* const kRTCScreenSharingExtension;

@class FlutterSocketConnectionFrameReader;
@class FlutterScreenAudioTrackCapturer;

@interface FlutterBroadcastScreenCapturer : RTCVideoCapturer
@property(nonatomic, strong, nullable) FlutterScreenAudioTrackCapturer *screenAudioCapturer;

- (void)startCapture;
- (void)stopCapture;
- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
