import 'dart:async';

import 'package:boohtacord_desktop/src/features/screen/capture/confirmed_dimensions.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

Map<String, dynamic> snapshot() => {
  'schema_version': 1,
  'status': 'active',
  'config_confirmed': true,
  'actual_width': 1920,
  'actual_height': 1246,
  'generation': 3,
};

class Media implements rtc.MediaStreamTrack {
  Media([this.settings = const {}]);
  final Map<String, dynamic> settings;
  @override
  String get id => 'owned-screen';
  @override
  Map<String, dynamic> getSettings() => settings;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Track implements LocalVideoTrack {
  Track([Map<String, dynamic> settings = const {}])
    : mediaStreamTrack = Media(settings);
  @override
  final rtc.MediaStreamTrack mediaStreamTrack;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Mac reads actual native dimensions once and encoder fits both axes',
    () async {
      var queries = 0;
      final dimensions = await readScreenCaptureDimensions(
        Track(),
        platform: TargetPlatform.macOS,
        isCurrent: () => true,
        readSnapshot: (id) async {
          expect(id, 'owned-screen');
          queries++;
          return snapshot();
        },
      );
      expect(queries, 1);
      expect(dimensions!.width, 1920);
      expect(dimensions.height, 1246);
      final scale = const ScreenShareQuality(resolution: 1080, frameRate: 60)
          .publishOptions(simulcast: false, sourceDimensions: dimensions)
          .screenShareEncoding!
          .scaleResolutionDownBy!;
      expect(dimensions.width ~/ scale, 1662);
      expect(dimensions.height ~/ scale, 1078);
    },
  );
  test('Mac native dimensions override logical settings', () async {
    final dimensions = await readScreenCaptureDimensions(
      Track({'width': 1280, 'height': 720}),
      platform: TargetPlatform.macOS,
      isCurrent: () => true,
      readSnapshot: (_) async => snapshot(),
    );
    expect(dimensions!.width, 1920);
    expect(dimensions.height, 1246);
  });
  test(
    'other platforms preserve settings and do not query Mac bridge',
    () async {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
      ]) {
        expect(
          await readScreenCaptureDimensions(
            Track(),
            platform: platform,
            isCurrent: () => true,
            readSnapshot: (_) async => fail('Unexpected query'),
          ),
          isNull,
        );
        final dimensions = await readScreenCaptureDimensions(
          Track({'width': 1280, 'height': 720}),
          platform: platform,
          isCurrent: () => true,
          readSnapshot: (_) async => fail('Unexpected query'),
        );
        expect(dimensions!.width, 1280);
        expect(dimensions.height, 720);
      }
    },
  );
  for (final invalid in [
    <String, dynamic>{
      'schema_version': 1,
      'status': 'unavailable',
      'config_confirmed': false,
    },
    {...snapshot(), 'config_confirmed': false},
    {...snapshot(), 'schema_version': 99},
    {...snapshot(), 'status': 'stopped'},
    {...snapshot(), 'actual_width': null},
    {...snapshot(), 'actual_height': 0},
    {...snapshot(), 'actual_width': '1920'},
    {...snapshot(), 'actual_width': 1.5},
    {...snapshot(), 'actual_height': double.nan},
    {...snapshot(), 'actual_width': 1000000000},
  ]) {
    test(
      'invalid/unavailable snapshot stays unknown ${invalid.keys.join(',')} ${invalid.values}',
      () async {
        expect(
          await readScreenCaptureDimensions(
            Track(),
            platform: TargetPlatform.macOS,
            isCurrent: () => true,
            readSnapshot: (_) async => invalid,
          ),
          isNull,
        );
      },
    );
  }
  test('native error remains unknown', () async {
    expect(
      await readScreenCaptureDimensions(
        Track(),
        platform: TargetPlatform.macOS,
        isCurrent: () => true,
        readSnapshot: (_) async => throw StateError('Unavailable'),
      ),
      isNull,
    );
  });
  test(
    'bounded timeout returns unknown; late completion is not cached',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var queries = 0;
      expect(
        await readScreenCaptureDimensions(
          Track(),
          platform: TargetPlatform.macOS,
          isCurrent: () => true,
          timeout: const Duration(milliseconds: 5),
          readSnapshot: (_) {
            queries++;
            return pending.future;
          },
        ),
        isNull,
      );
      pending.complete(snapshot());
      await Future<void>.delayed(Duration.zero);
      expect(queries, 1);
    },
  );
  test('already stale owner does not query native', () async {
    expect(
      await readScreenCaptureDimensions(
        Track(),
        platform: TargetPlatform.macOS,
        isCurrent: () => false,
        readSnapshot: (_) async => fail('Unexpected query'),
      ),
      isNull,
    );
  });
  test('stop or replacement during read suppresses dimensions', () async {
    final pending = Completer<Map<String, dynamic>>();
    var current = true;
    final result = readScreenCaptureDimensions(
      Track(),
      platform: TargetPlatform.macOS,
      isCurrent: () => current,
      readSnapshot: (_) => pending.future,
    );
    current = false;
    pending.complete(snapshot());
    expect(await result, isNull);
  });
}
