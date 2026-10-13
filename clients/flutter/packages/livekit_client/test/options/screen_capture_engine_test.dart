// Copyright 2026 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:livekit_client/src/track/options.dart';

void main() {
  test('default screen options preserve baseline constraints without engine', () {
    final constraints = const ScreenShareCaptureOptions(maxFrameRate: 30).toMediaConstraintsMap();
    expect((constraints['mandatory'] as Map?)?['captureEngine'], isNull);
  });
  test('macOS capture engine preserves exact source and frame rate', () {
    final constraints = const ScreenShareCaptureOptions(
      captureEngine: 'screen_capture_kit',
      sourceId: 'synthetic-window',
      maxFrameRate: 60,
    ).toMediaConstraintsMap();
    expect(constraints['deviceId'], {'exact': 'synthetic-window'});
    expect(constraints['mandatory'], {'frameRate': 60.0, 'captureEngine': 'screen_capture_kit'});
  }, skip: !Platform.isMacOS);
  test('copyWith keeps engine independently of audio and FPS changes', () {
    final next = const ScreenShareCaptureOptions(
      captureEngine: 'screen_capture_kit',
      maxFrameRate: 60,
    ).copyWith(captureScreenAudio: true, maxFrameRate: 30);
    expect(next.captureEngine, 'screen_capture_kit');
    expect(next.captureScreenAudio, true);
    expect(next.maxFrameRate, 30);
    expect(next.copyWith(captureEngine: 'baseline').captureEngine, 'baseline');
  });
  test('from constructor carries explicit engine without inventing one', () {
    const base = ScreenShareCaptureOptions();
    expect(ScreenShareCaptureOptions.from(captureOptions: base).captureEngine, isNull);
    expect(ScreenShareCaptureOptions.from(captureOptions: base, captureEngine: 'baseline').captureEngine, 'baseline');
  });
  test('diagnostics default leaves native default unchanged', () {
    const options = ScreenShareCaptureOptions();
    expect(options.captureDiagnosticsEnabled, isNull);
    expect((options.toMediaConstraintsMap()['mandatory'] as Map?)?['captureDiagnosticsEnabled'], isNull);
  });
  test('macOS diagnostics switch preserves engine source and frame rate', () {
    for (final enabled in [false, true]) {
      final constraints = ScreenShareCaptureOptions(
        captureDiagnosticsEnabled: enabled,
        captureEngine: 'screen_capture_kit',
        sourceId: 'synthetic-window',
        maxFrameRate: 60,
      ).toMediaConstraintsMap();
      expect(constraints['deviceId'], {'exact': 'synthetic-window'});
      expect(constraints['mandatory'], {
        'frameRate': 60.0,
        'captureEngine': 'screen_capture_kit',
        'captureDiagnosticsEnabled': enabled,
      });
    }
  }, skip: !Platform.isMacOS);
  test('diagnostics copyWith preserves explicit false and independent audio policy', () {
    final next = const ScreenShareCaptureOptions(
      captureDiagnosticsEnabled: false,
    ).copyWith(captureScreenAudio: true, maxFrameRate: 30);
    expect(next.captureDiagnosticsEnabled, false);
    expect(next.captureScreenAudio, true);
    expect(next.maxFrameRate, 30);
    expect(next.copyWith(captureDiagnosticsEnabled: true).captureDiagnosticsEnabled, true);
  });
  test('from constructor forwards explicit diagnostics without inventing one', () {
    const base = ScreenShareCaptureOptions();
    expect(ScreenShareCaptureOptions.from(captureOptions: base).captureDiagnosticsEnabled, isNull);
    expect(
      ScreenShareCaptureOptions.from(captureOptions: base, captureDiagnosticsEnabled: false).captureDiagnosticsEnabled,
      false,
    );
  });
}
