import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:boohtacord_desktop/src/features/telemetry/export/session_processor.dart';

void main() {
  test(
    'same-origin installation replacement invalidates telemetry ownership',
    () {
      final session = TelemetrySession(
        SessionScope().capture,
        () => 'https://synthetic.invalid',
      );
      session.bindInstallation('11111111-1111-4111-8111-111111111111');
      session.bind('a' * 32, '1');
      final previous = session.snapshot();
      session.bindInstallation('22222222-2222-4222-8222-222222222222');
      expect(session.current(previous), false);
      expect(session.binding, isNull);
    },
  );
  test('replacement session drops queued and late spans even if old owner is locally current', () async {
    TelemetrySession make(String id) {
      final s = TelemetrySession(
        SessionScope().capture,
        () => 'https://synthetic.invalid',
      );
      s.bind(id, '1');
      return s;
    }

    var current = make('1' * 32);
    final old = current, exported = <Uint8List>[];
    final processor = SessionSpanProcessor(
      (body) async => exported.add(body),
      () => current,
    );
    await OTel.initialize(
      serviceName: 'synthetic-qa',
      tracerName: 'qa',
      spanProcessor: processor,
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );
    addTearDown(OTel.shutdown);
    final late = OTel.tracer().startSpan('voice.join');
    OTel.tracer().startSpan('voice.leave').end();
    current = make('2' * 32);
    expect(old.current(old.snapshot()), true);
    late.end();
    await processor.forceFlush();
    expect(exported, isEmpty);
    OTel.tracer().startSpan('voice.join').end();
    await processor.forceFlush();
    expect(exported, hasLength(1));
    final encoded = latin1.decode(exported.single);
    expect(encoded, contains('2' * 32));
    expect(encoded, isNot(contains('1' * 32)));
  });
}
