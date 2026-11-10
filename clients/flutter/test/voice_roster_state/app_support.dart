import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

AppState ready(RosterApi api) {
  final state = AppState(
    api,
    voiceRosterStaleTimeout: const Duration(milliseconds: 100),
  );
  state.session.scope.begin();
  state.session.user = const SessionUser(
    accountId: 'account-1',
    role: 'MEMBER',
  );
  state.session.phase = AppPhase.ready;
  addTearDown(state.dispose);
  return state;
}
