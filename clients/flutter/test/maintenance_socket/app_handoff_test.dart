import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authenticated socket delivers maintenance and marks loss unknown',
    () async {
      final state = ready(RosterApi());
      await state.maintenance.useAuthenticated();
      state.realtime.onSocketStart?.call();
      await state.realtime.dispatch(
        const RealtimeEvent('event', 'maintenance.snapshot', {
          'version': 1,
          'generation': '11111111-1111-4111-8111-111111111111',
          'revision': 1,
          'active': true,
        }),
      );
      expect(state.maintenance.known, isTrue);
      expect(state.maintenanceActive, isTrue);
      state.realtime.onSocketEnd?.call();
      expect(state.maintenance.known, isFalse);
      expect(state.maintenanceActive, isTrue);
    },
  );
}
