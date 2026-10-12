//
//  FlutterSocketConnectionFrameReader.m
//  RCTWebRTC
//
//  Receives JPEG video frames and signed 16-bit PCM audio from ReplayKit.
//

#include <mach/mach_time.h>
#include <stdint.h>
#include <string.h>

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <ReplayKit/ReplayKit.h>
#import <WebRTC/RTCCVPixelBuffer.h>
#import <WebRTC/RTCVideoFrameBuffer.h>

#import "FlutterSocketConnection.h"
#import "FlutterSocketConnectionFrameReader.h"
#import "../ScreenAudioTrackCapturer.h"

static const NSUInteger kMaxSocketReadLength = 16 * 1024;
static const NSUInteger kMaxSocketHeaderLength = 8 * 1024;
static const NSUInteger kMaxSocketBodyLength = 32 * 1024 * 1024;
static const NSUInteger kMaxSocketFramePixels = 16 * 1024 * 1024;
static const UInt8 kHeaderTerminator[] = {'\r', '\n', '\r', '\n'};

@interface Message : NSObject

@property(nonatomic, assign, readonly) CVImageBufferRef imageBuffer;
@property(nonatomic, assign, readonly) int imageOrientation;
@property(nonatomic, copy, readonly, nullable) NSData *audioData;
@property(nonatomic, assign, readonly) int audioSampleRate;
@property(nonatomic, assign, readonly) size_t audioChannels;
@property(nonatomic, assign, readonly) size_t audioFrames;
@property(nonatomic, assign, readonly, getter=isAudio) BOOL audio;

- (instancetype)initWithHeaders:(NSDictionary<NSString *, NSString *> *)headers body:(NSData *)body;

@end

@interface Message ()

@property(nonatomic, assign) CVImageBufferRef imageBuffer;
@property(nonatomic, assign) int imageOrientation;
@property(nonatomic, copy, nullable) NSData *audioData;
@property(nonatomic, assign) int audioSampleRate;
@property(nonatomic, assign) size_t audioChannels;
@property(nonatomic, assign) size_t audioFrames;
@property(nonatomic, assign, getter=isAudio) BOOL audio;

@end

@implementation Message

- (instancetype)initWithHeaders:(NSDictionary<NSString *, NSString *> *)headers body:(NSData *)body {
  self = [super init];
  if (self == nil) return nil;
  _imageBuffer = NULL;

  NSString *contentType = headers[@"content-type"] ?: @"image/jpeg";
  if ([contentType caseInsensitiveCompare:@"audio/x-pcm-s16le"] == NSOrderedSame) {
    NSInteger sampleRate = [headers[@"buffer-sample-rate"] integerValue];
    NSInteger channels = [headers[@"buffer-channels"] integerValue];
    NSInteger frames = [headers[@"buffer-frames"] integerValue];
    if (sampleRate < 8000 || sampleRate > 96000 || (channels != 1 && channels != 2) || frames <= 0 ||
        (NSUInteger)frames > kMaxSocketBodyLength / ((NSUInteger)channels * sizeof(int16_t)) ||
        body.length != (NSUInteger)frames * (NSUInteger)channels * sizeof(int16_t)) {
      return nil;
    }
    _audio = YES;
    _audioSampleRate = (int)sampleRate;
    _audioChannels = (size_t)channels;
    _audioFrames = (size_t)frames;
    _audioData = body;
    return self;
  }

  NSInteger width = [headers[@"buffer-width"] integerValue];
  NSInteger height = [headers[@"buffer-height"] integerValue];
  if (width <= 0 || height <= 0 || width > 16384 || height > 16384 ||
      (NSUInteger)width > kMaxSocketFramePixels / (NSUInteger)height) {
    return nil;
  }
  _imageOrientation = [headers[@"buffer-orientation"] intValue];

  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, (size_t)width, (size_t)height,
                                        kCVPixelFormatType_32BGRA, NULL, &_imageBuffer);
  if (status != kCVReturnSuccess) {
    NSLog(@"FlutterBroadcast: CVPixelBufferCreate failed (%d)", status);
    return nil;
  }

  CVPixelBufferLockBaseAddress(_imageBuffer, 0);
  CIImage *image = [CIImage imageWithData:body];
  if (image == nil) {
    CVPixelBufferUnlockBaseAddress(_imageBuffer, 0);
    CVPixelBufferRelease(_imageBuffer);
    _imageBuffer = NULL;
    return nil;
  }
  [[self imageContext] render:image toCVPixelBuffer:_imageBuffer];
  CVPixelBufferUnlockBaseAddress(_imageBuffer, 0);
  return self;
}

- (void)dealloc {
  if (_imageBuffer != NULL) CVPixelBufferRelease(_imageBuffer);
}

- (CIContext *)imageContext {
  static CIContext *imageContext = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    imageContext = [[CIContext alloc] initWithOptions:nil];
  });
  return imageContext;
}

@end

@interface FlutterSocketConnectionFrameReader () <NSStreamDelegate>

@property(nonatomic, strong) FlutterSocketConnection *connection;
@property(nonatomic, strong) FlutterScreenAudioTrackCapturer *audioCapturer;
@property(nonatomic, strong) NSMutableData *incomingData;

@end

@implementation FlutterSocketConnectionFrameReader {
  mach_timebase_info_data_t _timebaseInfo;
  int64_t _startTimeStampNs;
}

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
  return [self initWithDelegate:delegate audioCapturer:nil];
}

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate
                    audioCapturer:(FlutterScreenAudioTrackCapturer *)audioCapturer {
  self = [super initWithDelegate:delegate];
  if (self) {
    mach_timebase_info(&_timebaseInfo);
    _audioCapturer = audioCapturer;
    _incomingData = [NSMutableData data];
  }
  return self;
}

- (void)startCaptureWithConnection:(FlutterSocketConnection *)connection {
  _startTimeStampNs = -1;
  self.connection = connection;
  [self.incomingData setLength:0];
  [self.connection openWithStreamDelegate:self];
}

- (void)stopCapture {
  [self.connection close];
  [self.incomingData setLength:0];
}

- (void)readBytesFromStream:(NSInputStream *)stream {
  UInt8 bytes[kMaxSocketReadLength];
  while (stream.hasBytesAvailable) {
    NSInteger count = [stream read:bytes maxLength:sizeof(bytes)];
    if (count < 0) {
      NSLog(@"FlutterBroadcast: socket read failed");
      [self stopCapture];
      return;
    }
    if (count == 0) return;
    [self.incomingData appendBytes:bytes length:(NSUInteger)count];
    if (![self processBufferedMessages]) {
      [self stopCapture];
      return;
    }
  }
}

- (BOOL)processBufferedMessages {
  while (self.incomingData.length > 0) {
    const UInt8 *bytes = self.incomingData.bytes;
    NSRange headerRange = NSMakeRange(NSNotFound, 0);
    if (self.incomingData.length >= sizeof(kHeaderTerminator)) {
      for (NSUInteger index = 0; index <= self.incomingData.length - sizeof(kHeaderTerminator); ++index) {
        if (memcmp(bytes + index, kHeaderTerminator, sizeof(kHeaderTerminator)) == 0) {
          headerRange = NSMakeRange(0, index);
          break;
        }
      }
    }

    if (headerRange.location == NSNotFound) {
      return self.incomingData.length <= kMaxSocketHeaderLength;
    }
    if (headerRange.length > kMaxSocketHeaderLength) return NO;

    NSData *headerData = [self.incomingData subdataWithRange:headerRange];
    NSString *headerText = [[NSString alloc] initWithData:headerData encoding:NSASCIIStringEncoding];
    if (headerText == nil) return NO;
    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    NSArray<NSString *> *lines = [headerText componentsSeparatedByString:@"\r\n"];
    for (NSUInteger index = 1; index < lines.count; ++index) {
      NSString *line = lines[index];
      NSRange colon = [line rangeOfString:@":"];
      if (colon.location == NSNotFound) continue;
      NSString *name = [[line substringToIndex:colon.location] lowercaseString];
      NSString *value = [[line substringFromIndex:colon.location + 1]
          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      headers[name] = value;
    }

    NSInteger contentLength = [headers[@"content-length"] integerValue];
    if (contentLength < 0 || (NSUInteger)contentLength > kMaxSocketBodyLength) return NO;
    NSUInteger bodyStart = NSMaxRange(headerRange) + sizeof(kHeaderTerminator);
    NSUInteger messageLength = bodyStart + (NSUInteger)contentLength;
    if (self.incomingData.length < messageLength) return YES;

    NSData *body = [self.incomingData subdataWithRange:NSMakeRange(bodyStart, (NSUInteger)contentLength)];
    Message *message = [[Message alloc] initWithHeaders:headers body:body];
    if (message == nil) return NO;
    if (message.isAudio) {
      [self.audioCapturer appendPCMData:message.audioData
                             sampleRate:message.audioSampleRate
                               channels:message.audioChannels
                                  frames:message.audioFrames];
    } else {
      [self didCaptureVideoFrame:message.imageBuffer withOrientation:message.imageOrientation];
    }
    [self.incomingData replaceBytesInRange:NSMakeRange(0, messageLength) withBytes:NULL length:0];
  }
  return YES;
}

- (void)didCaptureVideoFrame:(CVPixelBufferRef)pixelBuffer
             withOrientation:(CGImagePropertyOrientation)orientation {
  int64_t currentTime = mach_absolute_time();
  int64_t currentTimeStampNs = currentTime * _timebaseInfo.numer / _timebaseInfo.denom;
  if (_startTimeStampNs < 0) _startTimeStampNs = currentTimeStampNs;

  RTCCVPixelBuffer *rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
  int64_t frameTimeStampNs = currentTimeStampNs - _startTimeStampNs;
  RTCVideoRotation rotation;
  switch (orientation) {
    case kCGImagePropertyOrientationLeft: rotation = RTCVideoRotation_90; break;
    case kCGImagePropertyOrientationDown: rotation = RTCVideoRotation_180; break;
    case kCGImagePropertyOrientationRight: rotation = RTCVideoRotation_270; break;
    default: rotation = RTCVideoRotation_0; break;
  }

  RTCVideoFrame *videoFrame = [[RTCVideoFrame alloc] initWithBuffer:[rtcPixelBuffer toI420]
                                                           rotation:rotation
                                                        timeStampNs:frameTimeStampNs];
  [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}

@end

@implementation FlutterSocketConnectionFrameReader (NSStreamDelegate)

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
  switch (eventCode) {
    case NSStreamEventOpenCompleted:
      break;
    case NSStreamEventHasBytesAvailable:
      [self readBytesFromStream:(NSInputStream *)stream];
      break;
    case NSStreamEventEndEncountered:
      [self stopCapture];
      break;
    case NSStreamEventErrorOccurred:
      NSLog(@"FlutterBroadcast: socket stream failed");
      [self stopCapture];
      break;
    default:
      break;
  }
}

@end
