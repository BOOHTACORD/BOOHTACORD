import 'dart:convert';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/action.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:boohtacord_desktop/src/features/telemetry/export/session_processor.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TelemetrySession session;
  late SessionSpanProcessor processor;
  late List<Uint8List> exports;
  setUpAll(() async {
    session = TelemetrySession(
      SessionScope().capture,
      () => 'https://synthetic.invalid',
    );
    session.bind('1' * 32, '1');
    exports = [];
    processor = SessionSpanProcessor(
      (body) async => exports.add(body),
      () => session,
    );
    await OTel.initialize(
      serviceName: 'synthetic-qa',
      tracerName: 'qa',
      spanProcessor: processor,
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );
  });
  setUp(() {
    session.reset();
    session.bind('1' * 32, '1');
    exports.clear();
  });
  tearDownAll(OTel.shutdown);

  test('nested stale runs detach both action and OTel parent while preserving fresh ambient action', () async {
    final old = ActionScope('message.send', session, enabled: true);
    var productWork = 0;
    await old.run(() async {
      session.reset();
      session.bind('2' * 32, '1');
      await old.run(() async {
        await Future<void>.delayed(Duration.zero);
        productWork++;
        expect(ActionScope.current, isNull);
        expect(Context.current.spanContext, isNull);
      });
      final fresh = ActionScope('voice.join', session, enabled: true);
      await fresh.run(
        () => old.run(() async {
          expect(ActionScope.current, same(fresh));
          expect(Context.current.spanContext, fresh.span!.spanContext);
        }),
      );
      fresh.finish('success');
    });
    expect(productWork, 1);
    await processor.forceFlush();
    expect(exports, isNotEmpty);
    expect(exports.map(latin1.decode).join(), contains('voice.join'));
    expect(exports.map(latin1.decode).join(), contains('2' * 32));
  });

  test('late spans born directly in a stale async zone never adopt the replacement account', () async {
    final old = ActionScope('message.send', session, enabled: true);
    await old.run(() async {
      session.reset();
      session.bind('2' * 32, '1');
      await Future<void>.delayed(Duration.zero);
      OTel.tracer().startSpan('api.request').end();
    });
    await processor.forceFlush();
    expect(exports, isEmpty);
    OTel.tracer().startSpan('api.request').end();
    await processor.forceFlush();
    expect(exports, hasLength(1));
    expect(latin1.decode(exports.single), contains('2' * 32));
    expect(latin1.decode(exports.single), isNot(contains('1' * 32)));
  });
}
