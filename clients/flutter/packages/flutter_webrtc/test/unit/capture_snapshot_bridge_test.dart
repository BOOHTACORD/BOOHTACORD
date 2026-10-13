import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/capture_snapshot.dart';

void main() {
  test('unsupported platform returns unavailable without invoking native',
      () async {
    var calls = 0;
    final reader = CaptureSnapshotBridge(
        supported: false,
        invoke: (_, __) async {
          calls++;
          return null;
        });
    expect((await reader.read('synthetic-track'))['status'], 'unavailable');
    expect(calls, 0);
  });
  test('snapshot query binds exact track and preserves nullable actual fields',
      () async {
    final reader = CaptureSnapshotBridge(
        supported: true,
        invoke: (method, args) async {
          expect(method, 'mediaStreamTrackGetCaptureSnapshot');
          expect(args, {'trackId': 'synthetic-track'});
          return {
            'schema_version': 1,
            'status': 'pending',
            'config_confirmed': false,
            'configured_width': null,
            'actual_width': null,
            'frame_age_ms': null
          };
        });
    final snapshot = await reader.read('synthetic-track');
    expect(snapshot['config_confirmed'], false);
    expect(snapshot['configured_width'], null);
    expect(snapshot['actual_width'], null);
    expect(snapshot['frame_age_ms'], null);
  });
  test('old plugin and native error return unavailable without invented config',
      () async {
    for (final error in [
      MissingPluginException(),
      PlatformException(code: 'synthetic')
    ]) {
      final reader = CaptureSnapshotBridge(
          supported: true, invoke: (_, __) async => throw error);
      expect(await reader.read('synthetic-track'), {
        'schema_version': 1,
        'status': 'unavailable',
        'config_confirmed': false,
      });
    }
  });
  test('malformed native result cannot confirm capture', () async {
    for (final result in [
      null,
      123,
      {'schema_version': 99, 'config_confirmed': true}
    ]) {
      final reader = CaptureSnapshotBridge(
          supported: true, invoke: (_, __) async => result);
      expect((await reader.read('synthetic-track'))['config_confirmed'], false);
    }
  });
}
