import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';

RealtimeEvent maintenance(String kind, int revision, bool active) =>
    RealtimeEvent('event', kind, {
      'version': 1,
      'generation': '11111111-1111-4111-8111-111111111111',
      'revision': revision,
      'active': active,
    });

void main() {
  test('handoff rejects stale owner and retains unknown rather than false inactive', () {
    final state = MaintenanceSocketState();
    final guest = state.begin();
    expect(state.known, isFalse);
    expect(
      state.accept(guest, maintenance('maintenance.snapshot', 1, true)),
      isTrue,
    );
    expect(state.active, isTrue);
    final authenticated = state.begin();
    expect(state.known, isFalse);
    expect(state.active, isTrue);
    expect(
      state.accept(guest, maintenance('maintenance.changed', 2, false)),
      isFalse,
    );
    expect(
      state.accept(authenticated, maintenance('maintenance.snapshot', 1, true)),
      isTrue,
    );
    expect(
      state.accept(authenticated, maintenance('maintenance.changed', 2, false)),
      isTrue,
    );
    expect(state.active, isFalse);
    state.end(authenticated);
    expect(state.known, isFalse);
    state.dispose();
  });

  test('invalid order and stale revisions never replace the last state', () {
    final state = MaintenanceSocketState();
    expect(
      state.accept(0, maintenance('maintenance.snapshot', 1, false)),
      isFalse,
    );
    final token = state.begin();
    expect(
      state.accept(token, maintenance('maintenance.changed', 1, false)),
      isFalse,
    );
    expect(
      state.accept(token, maintenance('maintenance.snapshot', 4, true)),
      isTrue,
    );
    expect(
      state.accept(token, maintenance('maintenance.changed', 3, false)),
      isFalse,
    );
    expect(
      state.accept(token, maintenance('maintenance.snapshot', 5, false)),
      isFalse,
    );
    expect(state.active, isTrue);
    final next = state.begin();
    expect(
      state.accept(next, maintenance('maintenance.snapshot', 3, false)),
      isFalse,
    );
    expect(state.known, isFalse);
    state.dispose();
  });
}
