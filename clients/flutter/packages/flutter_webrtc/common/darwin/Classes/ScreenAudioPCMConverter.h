/*
 * Copyright (c) 2026 The BOOHTACORD contributors.
 * Licensed under the BSD 3-Clause license, matching the vendored WebRTC API.
 */

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

/// Copies a ReplayKit or ScreenCaptureKit audio sample into interleaved S16 PCM.
/// The output is mono or stereo and keeps the input sample rate.
FOUNDATION_EXPORT NSData * _Nullable FlutterScreenAudioPCMDataFromSampleBuffer(
    CMSampleBufferRef _Nullable sampleBuffer,
    int * _Nullable sampleRate,
    size_t * _Nullable channels,
    size_t * _Nullable frames);
