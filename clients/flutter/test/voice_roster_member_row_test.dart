import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/voice_prejoin/member_row.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('deafen status takes priority over microphone mute', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceRosterMemberRow(
            state: state,
            participant: const VoiceRosterMember(
              accountId: 'account-1',
              displayName: 'Мика',
              screenSharing: false,
              microphoneMuted: true,
              deafened: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.headset_off), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_outlined), findsNothing);
    expect(find.byTooltip('Не слышит участников'), findsOneWidget);
  });
}
