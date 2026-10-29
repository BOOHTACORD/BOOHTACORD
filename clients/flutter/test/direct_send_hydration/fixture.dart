import 'dart:async';
import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'image_data.dart';

const pair = DirectConversation(
  id: 'pair',
  participantId: 'peer',
  displayName: 'Peer',
  unreadCount: 0,
);

class SendFixture {
  SendFixture({this.extension = 'jpg', this.emptyAck = false}) {
    api = ApiClient(client: MockClient(request));
    state = AppState(api)
      ..phase = AppPhase.ready
      ..user = const SessionUser(accountId: 'owner', role: 'MEMBER');
    state.workspace.selectedDirectMessage = pair;
  }
  final String extension;
  final bool emptyAck;
  late final ApiClient api;
  late final AppState state;
  int posts = 0, historyReads = 0, receipts = 0;
  String? clientId;
  String sentBody = '';
  List<int>? originalBytes, previewBytes;
  Object? historyError;
  Completer<http.Response>? historyGate;
  Completer<http.Response>? postGate;
  final postRequested = Completer<void>();
  Map<String, dynamic> canonicalChanges = {};
  Map<String, dynamic> ackChanges = {};
  final historyRequested = Completer<void>();
  MessageAttachment get file => MessageAttachment(
    id: 'image',
    originalName: 'own.$extension',
    sizeBytes: originalBytes?.length ?? 205,
  );

  Map<String, dynamic> row({bool attachments = true}) => {
    'id': 'stored',
    'direct_message_id': pair.id,
    'author_id': 'owner',
    'client_message_id': clientId,
    'body': sentBody,
    'created_at': '2026-10-29T00:00:00Z',
    'revision': 1,
    if (attachments)
      'attachments': [
        {
          'id': file.id,
          'original_name': file.originalName,
          'byte_size': file.sizeBytes,
        },
      ],
  };

  http.Response response(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> request(http.Request request) async {
    final media = mediaResponse(request, originalBytes, previewBytes);
    if (media != null) return media;
    if (request.method == 'POST') {
      posts++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      clientId = body['client_message_id'] as String;
      sentBody = body['body'] as String;
      if (!postRequested.isCompleted) postRequested.complete();
      if (postGate case final gate?) return gate.future;
      return response({
        ...row(attachments: false),
        if (emptyAck) 'attachments': [],
        ...ackChanges,
      }, 201);
    }
    if (request.url.path.contains('/message-delivery/')) {
      receipts++;
      return response({'account_id': 'owner', 'message_id': 'stored'});
    }
    if (request.url.path.endsWith('/messages')) {
      historyReads++;
      if (!historyRequested.isCompleted) historyRequested.complete();
      if (historyError case final error?) throw error;
      if (historyGate case final gate?) return gate.future;
      return response({
        'messages': [
          {...row(), ...canonicalChanges},
        ],
      });
    }
    throw StateError(
      'Unexpected request ${request.method} ${request.url.path}',
    );
  }

  Future<bool> send() => state.sendDirect('', attachments: [file]);
  void dispose() => state.dispose();
}
