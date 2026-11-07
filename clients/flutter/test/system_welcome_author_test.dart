import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_row/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('loads missing welcome author and shows the actual name', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    const id = '11111111-1111-4111-8111-111111111111';
    var reads = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/members/$id')) {
          reads++;
          return http.Response(
            jsonEncode({
              'user_id': id,
              'login': 'alice',
              'display_name': 'Alice',
              'role': 'MEMBER',
              'presence': 'offline',
              'profile_revision': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    final state = AppState(api)
      ..user = const SessionUser(accountId: 'self', role: 'MEMBER');
    addTearDown(state.dispose);
    final message = ChatMessage(
      id: 'm',
      channelId: 'c',
      authorId: id,
      body: 'Welcome',
      createdAt: DateTime.utc(2026),
      deleted: false,
      revision: 1,
      clientMessageId: 'c',
      kind: 'SYSTEM_WELCOME',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceMessageRow(state: state, message: message),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('@Alice', findRichText: true), findsOneWidget);
    expect(reads, 1);
  });
}
