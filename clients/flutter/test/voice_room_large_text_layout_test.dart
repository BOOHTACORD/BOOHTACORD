import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_room/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('320dp voice cards remain readable at text scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 600);
      addTearDown(tester.view.reset);
      final room = Room();
      // ignore: invalid_use_of_internal_member
      final remote = await RemoteParticipant.createFromInfo(
        room: room,
        info: lk.ParticipantInfo(sid: 'sid-1', identity: 'one', name: 'One'),
      );
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 600),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: WorkspaceVoiceParticipantRoom(
                state: state,
                room: room,
                participants: [remote.participant],
                screens: const [],
                onScreenSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(
        find.byKey(const ValueKey('voice-participant-card:self')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('voice-participant-card:sid-1')),
      );
      if (scale == 2) {
        expect(first.width, greaterThanOrEqualTo(260));
        expect(second.top, greaterThanOrEqualTo(first.bottom));
        final other = find.byKey(
          const ValueKey('voice-participant-card:sid-1'),
        );
        await tester.ensureVisible(other);
        await tester.pumpAndSettle();
        expect(other.hitTestable(), findsOneWidget);
      } else {
        expect(first.top, second.top);
        expect(second.left, greaterThan(first.right));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(room.dispose);
    });
  }
}
