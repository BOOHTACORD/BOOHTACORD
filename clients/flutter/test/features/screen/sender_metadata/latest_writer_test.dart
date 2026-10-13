import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/api.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/latest_writer.dart';

Map<String, Object?> descriptor(int profile, {String state = 'sharing'}) => {
  'scope': {'operation_revision': 0},
  'profile_revision': profile,
  'publisher_state': state,
};

// Create a real local HTTP client without changing Flutter's global test override.
class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  test('actual truncated HTTP response recovers unchanged descriptor after cooldown', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = IOClient(_LoopbackHttpOverrides().createHttpClient(null));
    final api = ApiClient(client: client);
    api.transport.session.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    var healthy = false, now = Duration.zero;
    final requests = <String>[], bodies = <String>[], errors = <Object>[];
    final states = <ScreenDescriptorWriteStatus>[];
    final handlerErrors = <Object>[];
    final listener = server.listen((request) async {
      try {
        requests.add(request.method);
        await utf8.decoder.bind(request).join();
        if (healthy) {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
        } else {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.write(
            'HTTP/1.1 200 OK\r\nContent-Length: 64\r\nConnection: close\r\n\r\nx',
          );
          await socket.flush();
          socket.destroy();
        }
      } catch (error) {
        handlerErrors.add(error);
      }
    });
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        bodies.add(jsonEncode(value));
        try {
          await api.updateScreenProfileDescriptor(
            lease,
            value,
            abortTrigger: abort,
          );
        } catch (error) {
          errors.add(error);
          rethrow;
        }
      },
      changed: states.add,
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    try {
      writer.bind('synthetic-lease', () => true, operationRevision: 12);
      final chosen = descriptor(1);
      writer.offer(chosen);
      await writer.flush().timeout(const Duration(seconds: 5));
      expect(errors, isNotEmpty);
      expect(errors.first, isA<http.ClientException>());
      expect(errors.first, isNot(isA<SocketException>()));
      expect(errors.first, isNot(isA<http.RequestAbortedException>()));
      expect(bodies, hasLength(2));
      expect(states.last, ScreenDescriptorWriteStatus.unavailable);
      chosen['profile_revision'] = 99;
      healthy = true;
      now = const Duration(milliseconds: 4999);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(bodies, hasLength(2));
      now = const Duration(seconds: 5);
      writer.offer(descriptor(1));
      await writer.flush().timeout(const Duration(seconds: 5));
      expect(bodies, hasLength(3));
      expect(bodies.toSet(), hasLength(1));
      expect(
        (jsonDecode(bodies.last)['scope'] as Map)['operation_revision'],
        13,
      );
      expect(requests, ['PUT', 'PUT', 'PUT']);
      expect(states.last, ScreenDescriptorWriteStatus.applied);
      expect(handlerErrors, isEmpty);
    } finally {
      writer.invalidate();
      client.close();
      await listener.cancel();
      await server.close(force: true);
    }
  });

  for (final failure in <String, Object>{
    'socket': const SocketException('synthetic disconnect'),
    'HTTP client': http.ClientException('synthetic connection closed'),
  }.entries) {
    test(
      '${failure.key} loss has bounded waves and stable recovery revision',
      () async {
        var now = Duration.zero, healthy = false;
        final bodies = <String>[];
        final states = <ScreenDescriptorWriteStatus>[];
        final writer = LatestScreenProfileWriter(
          (lease, value, abort) async {
            bodies.add(jsonEncode(value));
            if (!healthy) throw failure.value;
          },
          changed: states.add,
          retryDelay: Duration.zero,
          monotonicElapsed: () => now,
        );
        writer.bind('lease', () => true, operationRevision: 8);
        writer.offer(descriptor(1));
        await writer.flush();
        expect(bodies, hasLength(2));
        healthy = true;
        writer.offer(descriptor(1));
        await writer.flush();
        expect(bodies, hasLength(2));
        now = const Duration(seconds: 5);
        writer.offer(descriptor(1));
        await writer.flush();
        expect(bodies, hasLength(3));
        expect(bodies.toSet(), hasLength(1));
        expect(
          (jsonDecode(bodies.last)['scope'] as Map)['operation_revision'],
          9,
        );
        expect(states.last, ScreenDescriptorWriteStatus.applied);
        writer.invalidate();
      },
    );
  }
  for (final failure in <String, Object>{
    'HTTP request abort': http.RequestAbortedException(),
    'descriptor abort': const ScreenProfileWriteAborted(),
    'TLS handshake': const HandshakeException('synthetic TLS rejection'),
  }.entries) {
    test('${failure.key} never retries unchanged state', () async {
      var now = Duration.zero, calls = 0;
      final writer = LatestScreenProfileWriter(
        (lease, value, abort) async {
          calls++;
          throw failure.value;
        },
        changed: (_) {},
        retryDelay: Duration.zero,
        monotonicElapsed: () => now,
      );
      writer.bind('lease', () => true);
      writer.offer(descriptor(1));
      await writer.flush();
      now = const Duration(days: 1);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, 1);
      writer.invalidate();
    });
  }
  test('late network failure from invalidated epoch cannot recover or affect new owner', () async {
    var now = Duration.zero;
    final gate = Completer<void>();
    final leases = <String>[], states = <ScreenDescriptorWriteStatus>[];
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        leases.add(lease);
        if (lease == 'old') {
          await gate.future;
          throw http.ClientException('synthetic connection lost');
        }
      },
      changed: states.add,
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    writer.bind('old', () => true);
    writer.offer(descriptor(1));
    writer.invalidate();
    writer.bind('new', () => true);
    writer.offer(descriptor(2));
    gate.complete();
    await writer.flush();
    expect(leases, ['old', 'new']);
    expect(
      states.where((value) => value == ScreenDescriptorWriteStatus.unavailable),
      isEmpty,
    );
    expect(states.last, ScreenDescriptorWriteStatus.applied);
    now = const Duration(days: 1);
    writer.offer(descriptor(2));
    await writer.flush();
    expect(leases, ['old', 'new']);
    writer.invalidate();
  });

  test(
    'retryable exhausted wave recovers identical body after monotonic cooldown',
    () async {
      var now = Duration.zero, healthy = false;
      final calls = <Map<String, Object?>>[],
          states = <ScreenDescriptorWriteStatus>[];
      final bodies = <String>[];
      final writer = LatestScreenProfileWriter(
        (lease, value, abort) async {
          calls.add(value);
          bodies.add(jsonEncode(value));
          if (!healthy) throw const ApiFailure('temporary', status: 503);
        },
        changed: states.add,
        retryDelay: Duration.zero,
        monotonicElapsed: () => now,
      );
      writer.bind('lease', () => true, operationRevision: 12);
      final original = descriptor(1);
      writer.offer(original);
      await writer.flush();
      original['profile_revision'] = 99;
      expect(calls, hasLength(2));
      expect(states.last, ScreenDescriptorWriteStatus.unavailable);
      healthy = true;
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, hasLength(2));
      now = const Duration(milliseconds: 4999);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, hasLength(2));
      now = const Duration(seconds: 5);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, hasLength(3));
      expect(calls[2], calls[0]);
      expect(bodies[2], bodies[0]);
      expect(bodies[1], bodies[0]);
      expect((calls[2]['scope'] as Map)['operation_revision'], 13);
      expect(states.last, ScreenDescriptorWriteStatus.applied);
      now = const Duration(seconds: 100);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, hasLength(3));
    },
  );
  test('timeout recovery waves remain two attempts with a cooldown, not a fixed lifetime count', () async {
    var now = Duration.zero, calls = 0;
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        calls++;
        throw TimeoutException('temporary');
      },
      changed: (_) {},
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    writer.bind('lease', () => true);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 2);
    now = const Duration(seconds: 5);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 4);
    now = const Duration(seconds: 9);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 4);
    now = const Duration(seconds: 10);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 6);
    writer.invalidate();
  });
  test(
    '400 401 403 404 unchanged state never automatically recovers',
    () async {
      for (final status in [400, 401, 403, 404]) {
        var now = Duration.zero, calls = 0;
        final writer = LatestScreenProfileWriter(
          (lease, value, abort) async {
            calls++;
            throw ApiFailure('rejected', status: status);
          },
          changed: (_) {},
          retryDelay: Duration.zero,
          monotonicElapsed: () => now,
        );
        writer.bind('lease', () => true);
        writer.offer(descriptor(1));
        await writer.flush();
        now = const Duration(days: 1);
        writer.offer(descriptor(1));
        await writer.flush();
        expect(calls, 1);
        writer.invalidate();
      }
    },
  );
  test('new semantic state clears old recovery and advances revision without cooldown', () async {
    var now = Duration.zero, healthy = false;
    final calls = <Map<String, Object?>>[];
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        calls.add(value);
        if (!healthy) throw const ApiFailure('temporary', status: 503);
      },
      changed: (_) {},
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    writer.bind('lease', () => true);
    writer.offer(descriptor(1));
    await writer.flush();
    healthy = true;
    writer.offer(descriptor(2));
    await writer.flush();
    expect(calls, hasLength(3));
    expect(calls.last['profile_revision'], 2);
    expect((calls.last['scope'] as Map)['operation_revision'], 2);
    now = const Duration(seconds: 10);
    writer.offer(descriptor(2));
    await writer.flush();
    expect(calls, hasLength(3));
  });
  test('invalidate and cancelPending clear recovery across epochs', () async {
    for (final invalidate in [false, true]) {
      var now = Duration.zero, healthy = false;
      final calls = <Map<String, Object?>>[];
      final writer = LatestScreenProfileWriter(
        (lease, value, abort) async {
          calls.add(value);
          if (!healthy) throw const ApiFailure('temporary', status: 503);
        },
        changed: (_) {},
        retryDelay: Duration.zero,
        monotonicElapsed: () => now,
      );
      writer.bind('lease', () => true);
      writer.offer(descriptor(1));
      await writer.flush();
      if (invalidate) {
        writer.invalidate();
        writer.bind('lease', () => true);
      } else {
        writer.cancelPending();
      }
      healthy = true;
      now = const Duration(seconds: 10);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, hasLength(3));
      expect((calls.last['scope'] as Map)['operation_revision'], 2);
    }
  });
  test('expired current owner cannot schedule cooldown recovery', () async {
    var now = Duration.zero, current = true, calls = 0;
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        calls++;
        throw const ApiFailure('temporary', status: 503);
      },
      changed: (_) {},
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    writer.bind('lease', () => current);
    writer.offer(descriptor(1));
    await writer.flush();
    current = false;
    now = const Duration(seconds: 10);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 2);
    current = true;
    now = const Duration(seconds: 20);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(
      calls,
      2,
      reason: 'expired ownership discarded the old recovery wave',
    );
    writer.invalidate();
  });
  test('latest queued state supersedes a failing recovery wave with one HTTP in flight', () async {
    var now = Duration.zero, initial = true;
    final gate = Completer<void>();
    final calls = <Map<String, Object?>>[];
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        calls.add(value);
        if (initial) throw const ApiFailure('temporary', status: 503);
        if (calls.length == 3) {
          await gate.future;
          throw const ApiFailure('temporary', status: 503);
        }
      },
      changed: (_) {},
      retryDelay: Duration.zero,
      monotonicElapsed: () => now,
    );
    writer.bind('lease', () => true);
    writer.offer(descriptor(1));
    await writer.flush();
    initial = false;
    now = const Duration(seconds: 5);
    writer.offer(descriptor(1));
    writer.offer(descriptor(2));
    writer.offer(descriptor(3));
    expect(calls, hasLength(3));
    expect(
      calls[2]['profile_revision'],
      1,
      reason: 'third request is the same-body recovery, not a premature newer request',
    );
    gate.complete();
    await writer.flush();
    expect(calls, hasLength(4));
    expect(calls.last['profile_revision'], 3);
    expect((calls.last['scope'] as Map)['operation_revision'], 3);
    now = const Duration(seconds: 100);
    writer.offer(descriptor(3));
    await writer.flush();
    expect(calls, hasLength(4));
  });

  test(
    'stop supersedes old request without resetting lease revision',
    () async {
      final calls = <Map<String, Object?>>[];
      var aborted = false;
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        calls.add(value);
        if (calls.length == 1) {
          await abort;
          aborted = true;
          throw StateError('cancelled');
        }
      }, changed: (_) {});
      writer.bind('lease', () => true);
      writer.offer(descriptor(1));
      await Future<void>.delayed(Duration.zero);
      writer.cancelPending();
      await Future<void>.delayed(Duration.zero);
      expect(aborted, isTrue);
      writer.offer(descriptor(1, state: 'idle'));
      await writer.flush();
      expect(calls.map((x) => (x['scope'] as Map)['operation_revision']), [
        1,
        2,
      ]);
    },
  );
  test('one HTTP in flight keeps only immutable latest state', () async {
    final calls = <Map<String, Object?>>[];
    final release = Completer<void>();
    final writer = LatestScreenProfileWriter((lease, value, abort) async {
      calls.add(value);
      if (calls.length == 1) await release.future;
    }, changed: (_) {});
    writer.bind('lease', () => true, operationRevision: 12);
    writer.offer(descriptor(1));
    await Future<void>.delayed(Duration.zero);
    writer.offer(descriptor(2));
    final newest = descriptor(3);
    writer.offer(newest);
    newest['profile_revision'] = 99;
    expect(calls, hasLength(1));
    release.complete();
    await writer.flush();
    expect(calls.map((x) => x['profile_revision']), [1, 3]);
    expect(calls.map((x) => (x['scope'] as Map)['operation_revision']), [
      13,
      15,
    ]);
  });

  test('retry reuses identical operation and is bounded', () async {
    final calls = <Map<String, Object?>>[];
    final states = <ScreenDescriptorWriteStatus>[];
    final writer = LatestScreenProfileWriter(
      (lease, value, abort) async {
        calls.add(value);
        throw const ApiFailure('temporary', status: 503);
      },
      changed: states.add,
      retryDelay: Duration.zero,
    );
    writer.bind('lease', () => true);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, hasLength(2));
    expect(calls.first, calls.last);
    expect(states.last, ScreenDescriptorWriteStatus.unavailable);
  });

  test('ACL rejection never retries', () async {
    var calls = 0;
    final writer = LatestScreenProfileWriter((lease, value, abort) async {
      calls++;
      throw const ApiFailure('forbidden', status: 403);
    }, changed: (_) {});
    writer.bind('lease', () => true);
    writer.offer(descriptor(1));
    await writer.flush();
    expect(calls, 1);
  });

  test(
    'old completion cannot mark new owner applied; abort delivered',
    () async {
      final release = Completer<void>();
      var aborted = false;
      var current = true;
      final states = <ScreenDescriptorWriteStatus>[];
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        if (lease == 'old') {
          unawaited(abort.then((_) => aborted = true));
          await release.future;
        }
      }, changed: states.add);
      writer.bind('old', () => current);
      writer.offer(descriptor(1));
      await Future<void>.delayed(Duration.zero);
      current = false;
      writer.bind('new', () => true);
      writer.offer(descriptor(2));
      await Future<void>.delayed(Duration.zero);
      expect(aborted, isTrue);
      release.complete();
      await writer.flush();
      expect(
        states.where((x) => x == ScreenDescriptorWriteStatus.applied),
        hasLength(1),
      );
    },
  );

  test(
    'same lease retains revision for higher idle clear and restart',
    () async {
      final calls = <Map<String, Object?>>[];
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        calls.add(value);
      }, changed: (_) {});
      writer.bind('lease', () => true, operationRevision: 8);
      writer.offer(descriptor(1));
      await writer.flush();
      writer.bind('lease', () => true);
      writer.offer(descriptor(1, state: 'idle'));
      await writer.flush();
      writer.offer(descriptor(2));
      await writer.flush();
      expect(calls.map((x) => (x['scope'] as Map)['operation_revision']), [
        9,
        10,
        11,
      ]);
    },
  );

  test(
    'invalid owner cannot send; duplicate snapshot does not republish',
    () async {
      var calls = 0;
      var valid = false;
      final writer = LatestScreenProfileWriter((lease, value, abort) async {
        calls++;
      }, changed: (_) {});
      writer.bind('lease', () => valid);
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, 0);
      valid = true;
      writer.offer(descriptor(1));
      await writer.flush();
      writer.offer(descriptor(1));
      await writer.flush();
      expect(calls, 1);
    },
  );
}
