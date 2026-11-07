import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_row/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_navigation_member_row/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_card/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const memberId = '11111111-1111-4111-8111-111111111111';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final surface in ['chat', 'voice sidebar', 'voice card']) {
    testWidgets('opens message action from $surface name', (tester) async {
      var opened = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/members/$memberId')) {
            return http.Response(
              jsonEncode({
                'user_id': memberId,
                'login': 'member',
                'display_name': 'Участник',
                'role': 'MEMBER',
                'presence': 'online',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.endsWith('/direct-messages')) {
            if (request.method == 'POST') {
              expect(jsonDecode(request.body)['participant_id'], memberId);
              opened = true;
              return http.Response('{"id":"dm-1"}', 200);
            }
            return http.Response(
              jsonEncode({
                'direct_messages': [
                  {
                    'id': 'dm-1',
                    'other_participant_id': memberId,
                    'other_participant_display_name': 'Friend',
                    'unread_count': 0,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.contains('/direct-messages/dm-1/messages')) {
            return http.Response('{"messages":[]}', 200);
          }
          return http.Response(
            jsonEncode({'can_pin': false, 'reactions': []}),
            200,
          );
        }),
      );
      final state = AppState(api)
        ..user = const SessionUser(accountId: 'self', role: 'MEMBER');
      addTearDown(state.dispose);
      final message = ChatMessage(
        id: 'm',
        channelId: 'c',
        authorId: memberId,
        body: 'text',
        createdAt: DateTime.utc(2026),
        deleted: false,
        revision: 1,
        clientMessageId: 'c',
      );
      final row = surface == 'voice card'
          ? WorkspaceVoiceParticipantCard(
              state: state,
              name: 'Участник',
              avatarUrl: null,
              avatarIdentity: memberId,
              memberAccountId: memberId,
              muted: false,
              speaking: false,
            )
          : surface == 'voice sidebar'
          ? WorkspaceVoiceNavigationMemberRow(
              state: state,
              name: 'Участник',
              accountId: memberId,
              muted: false,
              speaking: false,
              screenSharing: false,
            )
          : WorkspaceMessageRow(state: state, message: message);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: row)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('member-profile-trigger:$memberId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('member-profile-popover')),
        findsOneWidget,
      );
      expect(find.text('Сообщение'), findsOneWidget);
      await tester.tap(find.text('Сообщение'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(state.selectedDirectMessage?.id, 'dm-1');
    });
  }
}
