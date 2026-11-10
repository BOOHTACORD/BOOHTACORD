import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';

import '../realtime_scope/fakes.dart';
import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class FailingServerApi extends RosterApi {
  final sockets = <SocketFake>[];
  @override
  Future<WebSocket> openPublicRealtime() async {
    final socket = SocketFake();
    sockets.add(socket);
    return socket;
  }

  @override
  void abortPublicRealtime() {}
  @override
  Future<void> setBaseUrl(String value) async {
    throw StateError('test server failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed server change restores guest maintenance when signed out',
    () async {
      final api = FailingServerApi(), state = ready(api);
      state.session.user = null;
      state.session.phase = AppPhase.signedOut;
      await state.maintenance.useGuest();
      await Future<void>.delayed(Duration.zero);
      expect(api.sockets, hasLength(1));
      await expectLater(
        state.session.setServer('https://invalid.example'),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.sockets, hasLength(2));
      expect(api.sockets.first.closed, isTrue);
    },
  );
}
