//
//  FlutterSocketConnectionFrameReader.h
//  RCTWebRTC
//
//  Created by Alex-Dan Bumbu on 06/01/2021.
//

#import <AVFoundation/AVFoundation.h>
#import <WebRTC/RTCVideoCapturer.h>

NS_ASSUME_NONNULL_BEGIN

@class FlutterSocketConnection;
@class FlutterScreenAudioTrackCapturer;

@interface FlutterSocketConnectionFrameReader : RTCVideoCapturer

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;
- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate
                    audioCapturer:(nullable FlutterScreenAudioTrackCapturer *)audioCapturer;
- (void)startCaptureWithConnection:(nonnull FlutterSocketConnection*)connection;
- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END
