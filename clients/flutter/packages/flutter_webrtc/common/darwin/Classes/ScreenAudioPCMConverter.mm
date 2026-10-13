/*
 * Copyright (c) 2026 The BOOHTACORD contributors.
 * Licensed under the BSD 3-Clause license, matching the vendored WebRTC API.
 */

#import "ScreenAudioPCMConverter.h"

#import <AudioToolbox/AudioToolbox.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <vector>

NSData *FlutterScreenAudioPCMDataFromSampleBuffer(CMSampleBufferRef sampleBuffer,
                                                 int *sampleRate,
                                                 size_t *channels,
                                                 size_t *frames) {
  if (sampleBuffer == NULL || !CMSampleBufferIsValid(sampleBuffer) ||
      !CMSampleBufferDataIsReady(sampleBuffer)) {
    return nil;
  }

  CMAudioFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *format =
      description == NULL ? NULL : CMAudioFormatDescriptionGetStreamBasicDescription(description);
  if (format == NULL || format->mFormatID != kAudioFormatLinearPCM ||
      !std::isfinite(format->mSampleRate) || format->mSampleRate < 8000 ||
      format->mSampleRate > 96000 ||
      std::floor(format->mSampleRate) != format->mSampleRate ||
      static_cast<int>(format->mSampleRate) % 100 != 0 ||
      format->mChannelsPerFrame == 0 || format->mChannelsPerFrame > 2 ||
      (format->mFormatFlags & kAudioFormatFlagIsBigEndian) != 0) {
    return nil;
  }

  size_t listSize = 0;
  CMBlockBufferRef blockBuffer = NULL;
  OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, &listSize, NULL, 0, kCFAllocatorDefault, kCFAllocatorDefault,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
  if (status != noErr || listSize < sizeof(AudioBufferList)) {
    if (blockBuffer != NULL) CFRelease(blockBuffer);
    return nil;
  }

  AudioBufferList *buffers = (AudioBufferList *)calloc(1, listSize);
  if (buffers == NULL) {
    if (blockBuffer != NULL) CFRelease(blockBuffer);
    return nil;
  }
  status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, &listSize, buffers, listSize, kCFAllocatorDefault, kCFAllocatorDefault,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);

  const size_t sourceChannels = format->mChannelsPerFrame;
  const size_t outputChannels = sourceChannels == 1 ? 1 : 2;
  const size_t frameCount = CMSampleBufferGetNumSamples(sampleBuffer);
  const size_t bytesPerSample = format->mBitsPerChannel / 8;
  const bool isFloat = (format->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
  const bool isSigned = (format->mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0;
  const bool nonInterleaved = (format->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;

  if (status != noErr || buffers->mNumberBuffers == 0 || frameCount == 0 || frameCount > 96000 ||
      format->mSampleRate < 8000 || format->mSampleRate > 96000 || sourceChannels > 2 ||
      bytesPerSample == 0 ||
      (!isFloat && !isSigned)) {
    free(buffers);
    if (blockBuffer != NULL) CFRelease(blockBuffer);
    return nil;
  }

  const size_t requiredBuffers = nonInterleaved ? outputChannels : 1;
  if (buffers->mNumberBuffers < requiredBuffers) {
    free(buffers);
    if (blockBuffer != NULL) CFRelease(blockBuffer);
    return nil;
  }
  for (size_t channel = 0; channel < outputChannels; ++channel) {
    const size_t bufferIndex = nonInterleaved ? channel : 0;
    const size_t sourceSamples = nonInterleaved ? frameCount : frameCount * sourceChannels;
    if (buffers->mBuffers[bufferIndex].mData == NULL ||
        buffers->mBuffers[bufferIndex].mDataByteSize < sourceSamples * bytesPerSample) {
      free(buffers);
      if (blockBuffer != NULL) CFRelease(blockBuffer);
      return nil;
    }
  }

  std::vector<int16_t> pcm(frameCount * outputChannels);
  for (size_t frame = 0; frame < frameCount; ++frame) {
    for (size_t channel = 0; channel < outputChannels; ++channel) {
      const size_t bufferIndex = nonInterleaved ? channel : 0;
      const size_t sampleIndex = nonInterleaved ? frame : frame * sourceChannels + channel;
      const uint8_t *bytes = (const uint8_t *)buffers->mBuffers[bufferIndex].mData;
      double value = 0.0;
      if (isFloat && bytesPerSample == sizeof(float)) {
        float sample;
        std::memcpy(&sample, bytes + sampleIndex * bytesPerSample, sizeof(sample));
        value = sample;
      } else if (isFloat && bytesPerSample == sizeof(double)) {
        double sample;
        std::memcpy(&sample, bytes + sampleIndex * bytesPerSample, sizeof(sample));
        value = sample;
      } else if (isSigned && bytesPerSample == sizeof(int16_t)) {
        int16_t sample;
        std::memcpy(&sample, bytes + sampleIndex * bytesPerSample, sizeof(sample));
        value = (double)sample / 32768.0;
      } else if (isSigned && bytesPerSample == sizeof(int32_t)) {
        int32_t sample;
        std::memcpy(&sample, bytes + sampleIndex * bytesPerSample, sizeof(sample));
        value = (double)sample / 2147483648.0;
      } else {
        free(buffers);
        if (blockBuffer != NULL) CFRelease(blockBuffer);
        return nil;
      }
      value = std::clamp(value, -1.0, 1.0);
      pcm[frame * outputChannels + channel] = (int16_t)lrint(value * 32767.0);
    }
  }

  NSData *result = [NSData dataWithBytes:pcm.data() length:pcm.size() * sizeof(int16_t)];
  if (sampleRate != NULL) *sampleRate = (int)format->mSampleRate;
  if (channels != NULL) *channels = outputChannels;
  if (frames != NULL) *frames = frameCount;
  free(buffers);
  if (blockBuffer != NULL) CFRelease(blockBuffer);
  return result;
}
