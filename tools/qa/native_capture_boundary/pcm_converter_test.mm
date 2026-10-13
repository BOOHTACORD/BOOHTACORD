// Focused unit test of the real CoreMedia -> owned interleaved PCM converter.
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ScreenAudioPCMConverter.h"
#include <cassert>
#include <vector>

static NSData *Convert(double rate, size_t channels, size_t frames) {
  std::vector<int16_t> pcm(frames * channels, 1200);
  AudioStreamBasicDescription format{};
  format.mSampleRate = rate;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
  format.mBitsPerChannel = 16;
  format.mChannelsPerFrame = channels;
  format.mFramesPerPacket = 1;
  format.mBytesPerFrame = channels * sizeof(int16_t);
  format.mBytesPerPacket = format.mBytesPerFrame;
  CMAudioFormatDescriptionRef description = nullptr;
  assert(CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &format, 0, nullptr,
      0, nullptr, nullptr, &description) == noErr);
  CMBlockBufferRef block = nullptr;
  assert(CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, pcm.data(),
      pcm.size() * sizeof(int16_t), kCFAllocatorNull, nullptr, 0,
      pcm.size() * sizeof(int16_t), 0, &block) == noErr);
  CMSampleBufferRef sample = nullptr;
  assert(CMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault,
      block, description, frames, CMTimeMake(0, 48000), nullptr, &sample) == noErr);
  int actual_rate = 0;
  size_t actual_channels = 0, actual_frames = 0;
  NSData *result = FlutterScreenAudioPCMDataFromSampleBuffer(
      sample, &actual_rate, &actual_channels, &actual_frames);
  if (result) {
    assert(actual_rate == rate && actual_channels == channels && actual_frames == frames);
    assert(result.length == frames * channels * sizeof(int16_t));
    pcm.assign(pcm.size(), 0);
    assert(static_cast<const int16_t *>(result.bytes)[0] == 1200);
  }
  CFRelease(sample); CFRelease(block); CFRelease(description);
  return result;
}

int main() {
  @autoreleasepool {
    assert(Convert(48000, 1, 128) != nil);
    assert(Convert(48000, 2, 2048) != nil);
    assert(Convert(44100, 2, 256) != nil);
    assert(Convert(48000.5, 1, 128) == nil);
    assert(Convert(48000, 3, 128) == nil);
    puts("PASS: CoreMedia PCM ownership, mono/stereo, 44.1 kHz and unsupported-rate/channel rejection");
  }
}
