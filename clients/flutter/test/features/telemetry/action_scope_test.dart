import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/action.dart';

void main() {
  test(
    'a stale or finished action cannot become the context of later work',
    () async {
      final session = TelemetrySession(
        SessionScope().capture,
        () => 'https://synthetic.invalid',
      );
      session.bind('1' * 32, '1');
      final action = ActionScope('message.send', session);
      session.reset();
      session.bind('2' * 32, '1');
      await action.run(() async {
        expect(ActionScope.current, isNull);
      });
      final finished = ActionScope('voice.join', session);
      finished.finish('success');
      await finished.run(() async {
        expect(ActionScope.current, isNull);
      });
    },
  );

  test('cleanup runs once and cannot interrupt the action terminal', () {
    final session = TelemetrySession(
      SessionScope().capture,
      () => 'https://test.invalid',
    );
    final action = ActionScope('message.send', session);
    var count = 0;
    action.onFinish(() => throw StateError('synthetic cleanup'));
    action.onFinish(() => count++);
    expect(() => action.finish('cancelled'), returnsNormally);
    action.finish('success');
    expect(count, 1);
    expect(
      () => action.onFinish(() => throw StateError('late cleanup')),
      returnsNormally,
    );
  });
  test('concurrent Futures, retry and account/origin changes retain explicit contexts', () async {
    final tickets = SessionScope();
    var origin = 'https://one.invalid';
    final session = TelemetrySession(tickets.capture, () => origin);
    session.bind('11111111111111111111111111111111', '1');
    final records = <Map<String, Object>>[];
    final a = ActionScope('message.send', session, observe: records.add),
        b = ActionScope('voice.join', session, observe: records.add);
    await Future.wait([
      a.run(() async {
        await Future<void>.delayed(Duration.zero);
        expect(ActionScope.current, a);
        a.step('ack');
      }),
      b.run(() async {
        await Future<void>.delayed(Duration.zero);
        expect(ActionScope.current, b);
        b.step('connect');
      }),
    ]);
    a.finish('success');
    a.finish('failed');
    final retry = a.retry();
    retry.finish('timeout', reason: 'deadline');
    b.finish('cancelled');
    expect(records.where((r) => r['app.flow.record'] == 'terminal').length, 3);
    expect(a.id, isNot(b.id));
    expect(retry.id, a.id);
    expect(retry.attempt, 2);
    final old = ActionScope('screen.view', session, observe: records.add);
    origin = 'https://two.invalid';
    old.finish('success');
    final resetRetry = old.retry();
    expect(resetRetry.id, isNot(old.id));
    expect(resetRetry.attempt, 1);
    resetRetry.finish('cancelled');
    expect(
      records.where(
        (r) => r['app.flow.id'] == old.id && r['app.flow.record'] == 'terminal',
      ),
      isEmpty,
    );
  });
  test('closed SessionTicket blocks old callback even with unchanged diagnostic binding', () {
    final scope = SessionScope();
    final session = TelemetrySession(
      scope.capture,
      () => 'https://test.invalid',
    );
    final records = <Map<String, Object>>[],
        a = ActionScope('screen.view', session, observe: records.add);
    scope.close();
    a.finish('success');
    expect(records.where((r) => r['app.flow.record'] == 'terminal'), isEmpty);
  });

  test('media correlation uses the server-issued lease handle and clears it on leave', () {
    final session = TelemetrySession(
      SessionScope().capture,
      () => 'https://test.invalid',
    );
    session.beginMedia();
    session.mediaFlow = 'a' * 32;
    expect(
      session.bindMediaLease('11111111-1111-4111-8111-111111111111'),
      isTrue,
    );
    expect(session.snapshot().media, '11111111111141118111111111111111');
    expect(session.snapshot().mediaFlow, 'a' * 32);
    expect(session.snapshot().leaseId, '11111111-1111-4111-8111-111111111111');
    expect(session.bindMediaLease('not-a-lease'), isFalse);
    session.endMedia();
    expect(session.snapshot().media, isNull);
    expect(session.snapshot().leaseId, isNull);
    expect(session.snapshot().mediaFlow, isNull);
  });
}
