import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/conversation_scroll_memory.dart';

void main() {
  test(
    'scroll anchors survive serialization and DM/channel keys are isolated',
    () {
      ConversationScrollMemory.clear();
      ConversationScrollMemory.save(
        accountId: 'a',
        channelId: 'dm:c',
        offset: 42,
        followLatest: false,
        epoch: ConversationScrollMemory.epoch,
        anchorId: 'message',
        anchorOffset: -12,
      );
      final values = ConversationScrollMemory.exportForAccount('a');
      ConversationScrollMemory.clear();
      ConversationScrollMemory.importForAccount('a', values);
      expect(ConversationScrollMemory.load('a', 'dm:c')?.anchorId, 'message');
      expect(ConversationScrollMemory.load('a', 'dm:c')?.anchorOffset, -12);
      expect(ConversationScrollMemory.load('a', 'c'), isNull);
      expect(ConversationScrollMemory.load('b', 'dm:c'), isNull);
    },
  );
}
