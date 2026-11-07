import 'dart:async';
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
  testWidgets('late response from old session cannot reveal old profile', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    const id = '11111111-1111-4111-8111-111111111111';
    final pending = <Completer<http.Response>>[];
    final state = AppState(
      ApiClient(
        client: MockClient((r) {
          final c = Completer<http.Response>();
          pending.add(c);
          return c.future;
        }),
      ),
    )..user = const SessionUser(accountId: 'self', role: 'MEMBER');
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
    expect(pending.length, 1);
    state.session.scope.begin();
    state.notifyListeners();
    await tester.pump();
    expect(pending.length, 2);
    pending[0].complete(
      http.Response(
        jsonEncode({
          'user_id': id,
          'login': 'old',
          'display_name': 'Old',
          'role': 'MEMBER',
          'presence': 'offline',
          'profile_revision': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pump();
    expect(find.textContaining('@Old', findRichText: true), findsNothing);
    pending[1].complete(
      http.Response(
        jsonEncode({
          'user_id': id,
          'login': 'new',
          'display_name': 'New',
          'role': 'MEMBER',
          'presence': 'offline',
          'profile_revision': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('@New', findRichText: true), findsOneWidget);
  });
}
