import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app/notification_access/target.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

const conversation = '11111111-1111-4111-8111-111111111111';
const message = '22222222-2222-4222-8222-222222222222';

class TargetApi extends ApiClient {
  int read = 0, requested = 0;
  bool deleted = false;
  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async {
    expect(id, conversation);
    expect(at, message);
    requested++;
    return DirectChatMessagePage(
      messages: [
        DirectChatMessage(
          id: message,
          directMessageId: id,
          authorId: 'synthetic',
          body: 'Synthetic',
          createdAt: DateTime.utc(2026, 10, 25),
          deleted: deleted,
          revision: 1,
        ),
      ],
    );
  }

  @override
  Future<void> advanceDirectMessageReadCursor(
    String id,
    String messageId,
  ) async {
    read++;
  }
}

void main() {
  test(
    'tap resolves the exact authorized message without advancing read',
    () async {
      final api = TargetApi(),
          target = {
            'version': 1,
            'kind': 'DM',
            'conversation_id': conversation,
            'message_id': message,
          };
      final found = await resolveNotificationMessage(api, target);
      expect(found?.id, message);
      expect(found?.kind, SearchMessageKind.directMessage);
      expect(api.read, 0);
      api.deleted = true;
      expect(await resolveNotificationMessage(api, target), isNull);
      expect(api.read, 0);
      expect(
        await resolveNotificationMessage(api, {...target, 'kind': 'VOICE'}),
        isNull,
      );
      expect(api.requested, 2);
      api.transport.client.close();
    },
  );
}
