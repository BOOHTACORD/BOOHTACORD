import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/latest_writer.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/runtime.dart';

void main() {
  test(
    'lost native confirmation clears freshness and rejects an old HTTP ack',
    () async {
      final network = Completer<void>();
      Map<String, Object?>? confirmation = {
        'capture': {'max_fps': 30},
        'encoding': {
          'layers': [1],
        },
      };
      late ScreenDescriptorRuntime runtime;
      final writer = LatestScreenProfileWriter(
        (lease, value, abort) => network.future,
        changed: (status) => runtime.recordWriteStatus(status),
      );
      runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () async => confirmation,
        readIntent: () => {
          'mode': 'motion',
          'requested_profile_id': 'P1080_30',
        },
        changed: () {},
      );
      runtime.activate('lease', {'operation_revision': 0}, () => true);
      await runtime.refresh();
      expect(runtime.confirmedAt, isNotNull);
      confirmation = null;
      await runtime.refresh();
      expect(runtime.confirmedAt, isNull);
      expect(runtime.appliedAt, isNull);
      expect(
        runtime.lastDescriptor,
        isNotNull,
        reason: 'retain only as previous',
      );
      network.complete();
      await writer.flush();
      expect(runtime.status, ScreenDescriptorWriteStatus.pending);
      expect(runtime.appliedAt, isNull);
      runtime.invalidate();
    },
  );
  testWidgets(
    'binding owns periodic sampling; runtime starts no second polling loop',
    (tester) async {
      var reads = 0;
      final writer = LatestScreenProfileWriter(
        (lease, value, abort) async {},
        changed: (_) {},
      );
      final runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () async {
          reads++;
          return null;
        },
        readIntent: () => {
          'mode': 'motion',
          'requested_profile_id': 'P1080_60',
        },
        changed: () {},
      );
      runtime.activate('lease', {'operation_revision': 0}, () => true);
      await tester.pump(const Duration(seconds: 3));
      expect(reads, 0);
      runtime.invalidate();
    },
  );
  test(
    'publication replacement invalidates a read even when account stays active',
    () async {
      final read = Completer<Map<String, Object?>?>();
      var captureCurrent = true, writes = 0;
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        writes++;
      }, changed: (_) {});
      final runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () => read.future,
        readIntent: () => {
          'mode': 'motion',
          'requested_profile_id': 'P1080_60',
        },
        changed: () {},
      );
      runtime.activate(
        'lease',
        {'operation_revision': 0},
        () => true,
        captureCurrent: () => captureCurrent,
      );
      final pending = runtime.refresh();
      captureCurrent = false;
      read.complete({
        'capture': {'max_fps': 30},
        'encoding': {
          'layers': [1],
        },
      });
      await pending;
      await writer.flush();
      expect(writes, 0);
      expect(runtime.lastDescriptor, isNull);
      runtime.invalidate();
    },
  );
  test(
    'missing confirmation holds pending without invented descriptor',
    () async {
      var writes = 0;
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        writes++;
      }, changed: (_) {});
      final runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () async => null,
        readIntent: () => {
          'mode': 'motion',
          'requested_profile_id': 'P1080_60',
        },
        changed: () {},
      );
      runtime.activate('lease', {'operation_revision': 0}, () => true);
      await runtime.refresh();
      await writer.flush();
      expect(writes, 0);
      expect(runtime.status, ScreenDescriptorWriteStatus.pending);
      expect(runtime.lastDescriptor, isNull);
      runtime.invalidate();
    },
  );
  test(
    'stop cannot await HTTP and queues newer idle without stale read',
    () async {
      final calls = <Map<String, Object?>>[];
      final network = Completer<void>();
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        calls.add(value);
        if (calls.length == 1) await network.future;
      }, changed: (_) {});
      final runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () async => {
          'capture': {'max_fps': 30},
          'encoding': {
            'layers': [1],
          },
        },
        readIntent: () => {'mode': 'text', 'requested_profile_id': 'P1080_60'},
        changed: () {},
      );
      runtime.activate('lease', {'operation_revision': 0}, () => true);
      await runtime.refresh();
      runtime.stop();
      expect(calls, hasLength(1));
      network.complete();
      await writer.flush();
      expect(calls.map((x) => x['publisher_state']), ['sharing', 'idle']);
    },
  );
  test(
    'late confirmed read after logout cannot publish or change state',
    () async {
      final read = Completer<Map<String, Object?>?>();
      var writes = 0;
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        writes++;
      }, changed: (_) {});
      final runtime = ScreenDescriptorRuntime(
        writer: writer,
        readConfirmed: () => read.future,
        readIntent: () => {
          'mode': 'motion',
          'requested_profile_id': 'P1080_30',
        },
        changed: () {},
      );
      runtime.activate('lease', {'operation_revision': 0}, () => true);
      final pending = runtime.refresh();
      runtime.invalidate();
      read.complete({
        'capture': {'max_fps': 30},
        'encoding': {
          'layers': [1],
        },
      });
      await pending;
      await writer.flush();
      expect(writes, 0);
      expect(runtime.lastDescriptor, isNull);
    },
  );
}
