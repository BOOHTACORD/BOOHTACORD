import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/telemetry/model.dart';
import 'package:boohtacord_desktop/src/features/admin/telemetry/controller.dart';

Map<String, dynamic> fixture() => {
  'installation_id': 'test-installation',
  'mode': 'local_only',
  'state': 'disabled',
  'registered': false,
  'last_accepted_at': null,
  'queued': 0,
  'dropped': 0,
};
void main() {
  test(
    'parses all server states and rejects malformed counters and unknown state',
    () {
      for (final state in [
        'disabled',
        'unavailable',
        'never_connected',
        'exporting',
        'degraded',
        'revoked',
        'stale',
      ]) {
        expect(
          TelemetrySettings.fromJson({...fixture(), 'state': state}).state,
          state,
        );
      }
      for (final patch in [
        {'queued': -1},
        {'dropped': 1.5},
        {'registered': 'yes'},
        {'state': 'success'},
        {'mode': 'unknown'},
      ]) {
        expect(
          () => TelemetrySettings.fromJson({...fixture(), ...patch}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'opening reads only; central needs explicit consent and HTTPS',
    () async {
      var writes = 0;
      final owner = TelemetrySettingsController(
        () async => TelemetrySettings.fromJson(fixture()),
        (mode, endpoint, confirmed) async {
          writes++;
          return TelemetrySettings.fromJson(fixture());
        },
      );
      addTearDown(owner.dispose);
      await owner.load();
      expect(writes, 0);
      await owner.update(
        'central',
        endpoint: 'https://center.example',
        confirmed: false,
      );
      await owner.update(
        'central',
        endpoint: 'http://center.example',
        confirmed: true,
      );
      expect(writes, 0);
      await owner.update(
        'central',
        endpoint: 'https://center.example',
        confirmed: true,
      );
      expect(writes, 1);
    },
  );
  test('failed refresh clears formerly successful state', () async {
    var failRead = false;
    final owner = TelemetrySettingsController(() async {
      if (failRead) throw StateError('offline');
      return TelemetrySettings.fromJson(fixture());
    }, (_, _, _) async => TelemetrySettings.fromJson(fixture()));
    addTearDown(owner.dispose);
    await owner.load();
    expect(owner.value, isNotNull);
    failRead = true;
    await owner.load();
    expect(owner.value, isNull);
    expect(owner.error, isNotNull);
  });
  test('busy requests and stale account responses cannot publish', () async {
    final pending = Completer<TelemetrySettings>();
    var reads = 0, active = true;
    final owner = TelemetrySettingsController(
      () {
        reads++;
        return pending.future;
      },
      (_, _, _) async => TelemetrySettings.fromJson(fixture()),
      isCurrent: () => active,
    );
    addTearDown(owner.dispose);
    final first = owner.load();
    await owner.load();
    expect(reads, 1);
    active = false;
    pending.complete(TelemetrySettings.fromJson(fixture()));
    await first;
    expect(owner.value, isNull);
  });
}
