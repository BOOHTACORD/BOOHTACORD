import 'dart:convert';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=test-session',
    });
  });

  test('requests a cursor page for channel history', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'messages': [_textMessage],
              'next_cursor': 'older-message',
            }),
          ),
          200,
        );
      }),
    );

    final page = await api.messagePage('text-1', before: 'cursor-1');

    expect(request.url.path, '/api/v1/channels/text-1/messages');
    expect(request.url.queryParameters, {'before': 'cursor-1'});
    expect(request.headers['cookie'], 'session=test-session');
    expect(page.messages.single.id, 'message-1');
    expect(page.messages.single.clientMessageId, 'client-text-1');
    expect(page.messages.single.attachments.single.originalName, 'image.png');
    expect(page.nextCursor, 'older-message');
  });

  test('requests a cursor page for participant-scoped DM history', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'messages': [_directMessage],
              'next_cursor': 'older-dm-message',
            }),
          ),
          200,
        );
      }),
    );

    final page = await api.directMessageHistoryPage('dm-1', before: 'cursor-2');

    expect(request.url.path, '/api/v1/direct-messages/dm-1/messages');
    expect(request.url.queryParameters, {'before': 'cursor-2'});
    expect(request.headers['cookie'], 'session=test-session');
    expect(page.messages.single.id, 'dm-message-1');
    expect(page.messages.single.clientMessageId, 'client-dm-1');
    expect(page.messages.single.attachments.single.id, 'attachment-2');
    expect(page.nextCursor, 'older-dm-message');
  });

  test('requests history around a search hit', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'messages': [_textMessage],
            }),
          ),
          200,
        );
      }),
    );

    final page = await api.messagePage('text-1', at: 'message-1');

    expect(request.url.queryParameters, {'at': 'message-1', 'limit': '20'});
    expect(page.messages.single.id, 'message-1');
  });

  test('searches with query and optional conversation scope', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'messages': [
                {
                  'id': '00000000-0000-4000-8000-000000000003',
                  'kind': 'CHANNEL',
                  'channel_id': '00000000-0000-4000-8000-000000000001',
                  'author_id': '00000000-0000-4000-8000-000000000002',
                  'body': 'Найденный текст',
                  'created_at': '2026-09-20T00:00:00Z',
                  'revision': 1,
                },
              ],
              'next_cursor': 'older-hit',
            }),
          ),
          200,
        );
      }),
    );

    final page = await api.searchMessages('точная фраза', channelId: 'text-1');

    expect(request.url.path, '/api/v1/search/messages');
    expect(request.url.queryParameters, {
      'query': 'точная фраза',
      'channel_id': 'text-1',
      'limit': '20',
    });
    expect(
      page.messages.single.conversationId,
      '00000000-0000-4000-8000-000000000001',
    );
    expect(page.nextCursor, 'older-hit');
  });

  test(
    'sends reply and mention IDs in channel and DM message contracts',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final isDirect = request.url.path.contains('/direct-messages/');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                ...(isDirect ? _directMessage : _textMessage),
                'body': body['body'],
                'reply_to_id': body['reply_to_id'],
                'mention_user_ids': body['mention_user_ids'],
              }),
            ),
            200,
          );
        }),
      );

      await api.sendMessage(
        'text-1',
        'client-1',
        'Ответ',
        replyToId: 'message-parent',
        mentionUserIds: ['account-2'],
        attachmentIds: ['attachment-text'],
      );
      await api.sendDirectMessage(
        'dm-1',
        'client-2',
        'Ответ в DM',
        replyToId: 'dm-parent',
        mentionUserIds: ['account-2'],
        attachmentIds: ['attachment-dm'],
      );

      expect(requests, hasLength(2));
      expect(requests.last.headers['x-boohtacord-support-publication'], 'v1');
      for (final request in requests) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['reply_to_id'], contains('parent'));
        expect(body['mention_user_ids'], ['account-2']);
        expect(
          (body['attachment_ids'] as List).single,
          startsWith('attachment-'),
        );
      }
    },
  );

  test('edit requests preserve or clear the full mention set', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              request.url.path.contains('/direct-messages/')
                  ? _directMessage
                  : _textMessage,
            ),
          ),
          200,
        );
      }),
    );

    await api.editMessage(
      'text-1',
      'message-1',
      'Текст',
      1,
      mentionUserIds: ['account-2'],
    );
    await api.editDirectMessage(
      'dm-1',
      'message-1',
      'Лично',
      1,
      mentionUserIds: [],
    );

    expect((jsonDecode(requests[0].body) as Map)['mention_user_ids'], [
      'account-2',
    ]);
    expect((jsonDecode(requests[1].body) as Map)['mention_user_ids'], isEmpty);
  });

  test(
    'uploads a private attachment as multipart and validates metadata',
    () async {
      late http.Request request;
      final progress = <(int, int)>[];
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'id': 'attachment-1',
                'original_name': 'image.png',
                'byte_size': 3,
              }),
            ),
            201,
          );
        }),
      );

      final uploaded = await api.uploadChannelAttachment(
        'text-1',
        'image.png',
        Uint8List.fromList([137, 80, 78]),
        onProgress: (sent, total) => progress.add((sent, total)),
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/channels/text-1/attachments');
      expect(request.headers['cookie'], 'session=test-session');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(latin1.decode(request.bodyBytes), contains('image.png'));
      expect(uploaded.id, 'attachment-1');
      expect(uploaded.sizeBytes, 3);
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
    },
  );

  test(
    'fetches protected attachment previews with the session cookie',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes([137, 80, 78, 71], 200);
        }),
      );

      final bytes = await api.messageAttachmentBytes(
        '/channels/text-1',
        'file ?#',
        preview: true,
      );

      expect(bytes, [137, 80, 78, 71]);
      expect(
        request.url.path,
        '/api/v1/channels/text-1/attachments/file%20%3F%23/preview',
      );
      expect(request.headers['accept'], 'image/*');
      expect(request.headers['cookie'], 'session=test-session');
    },
  );
}

const _textMessage = {
  'id': 'message-1',
  'client_message_id': 'client-text-1',
  'channel_id': 'text-1',
  'author_id': 'account-1',
  'body': 'Старое',
  'created_at': '2026-09-20T00:00:00Z',
  'deleted': false,
  'revision': 1,
  'attachments': [
    {'id': 'attachment-1', 'original_name': 'image.png', 'byte_size': 3},
  ],
};

const _directMessage = {
  'id': 'dm-message-1',
  'client_message_id': 'client-dm-1',
  'direct_message_id': 'dm-1',
  'author_id': 'account-2',
  'body': 'Старое личное',
  'created_at': '2026-09-20T00:00:00Z',
  'deleted': false,
  'revision': 1,
  'attachments': [
    {'id': 'attachment-2', 'original_name': 'dm.pdf', 'byte_size': 128},
  ],
};
