import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ComposerDraftMemory.clear);

  test(
    'async restore preserves fresh edits and explicit empty draft tombstones',
    () {
      final revision = ComposerDraftMemory.revision;
      for (final conversation in ['edited', 'cleared']) {
        ComposerDraftMemory.save(
          'a',
          ComposerDraftKind.channel,
          conversation,
          ComposerDraft(
            body: conversation == 'edited' ? 'new' : '',
            replyTarget: null,
            attachments: const [],
            mentionUserIds: const [],
          ),
        );
      }
      ComposerDraftMemory.importForAccount('a', [
        for (final conversation in ['edited', 'cleared', 'untouched'])
          {
            'kind': 'channel',
            'conversation': conversation,
            'body': 'old',
            'reply_id': 'not-loaded',
          },
      ], unchangedSince: revision);
      expect(
        ComposerDraftMemory.load<Object>(
          'a',
          ComposerDraftKind.channel,
          'edited',
        )?.body,
        'new',
      );
      expect(
        ComposerDraftMemory.load<Object>(
          'a',
          ComposerDraftKind.channel,
          'cleared',
        ),
        isNull,
      );
      expect(
        ComposerDraftMemory.exportForAccount('a')
            .where((e) => e['conversation'] == 'untouched')
            .single['reply_id'],
        'not-loaded',
      );
    },
  );

  test('keeps drafts isolated by account, kind, and conversation', () {
    final attachment = const MessageAttachment(
      id: 'attachment-1',
      originalName: 'notes.txt',
      sizeBytes: 12,
    );
    final reply = _message('reply-1');
    final mentions = ['account-2'];
    final attachments = [attachment];
    ComposerDraftMemory.save(
      'account-1',
      ComposerDraftKind.channel,
      'channel-1',
      ComposerDraft(
        body: 'черновик',
        replyTarget: reply,
        attachments: attachments,
        mentionUserIds: mentions,
      ),
    );
    mentions.clear();
    attachments.clear();

    final restored = ComposerDraftMemory.load<ChatMessage>(
      'account-1',
      ComposerDraftKind.channel,
      'channel-1',
    );
    expect(restored?.body, 'черновик');
    expect(restored?.replyTarget?.id, 'reply-1');
    expect(restored?.attachments.single.id, 'attachment-1');
    expect(restored?.mentionUserIds, ['account-2']);
    expect(
      ComposerDraftMemory.load<ChatMessage>(
        'account-2',
        ComposerDraftKind.channel,
        'channel-1',
      ),
      isNull,
    );
    expect(
      ComposerDraftMemory.load<ChatMessage>(
        'account-1',
        ComposerDraftKind.directMessage,
        'channel-1',
      ),
      isNull,
    );
    expect(
      ComposerDraftMemory.load<ChatMessage>(
        'account-1',
        ComposerDraftKind.channel,
        'channel-2',
      ),
      isNull,
    );
  });

  test(
    'removes empty drafts and invalidates mounted composer writers on clear',
    () {
      ComposerDraftMemory.save(
        'account-1',
        ComposerDraftKind.channel,
        'channel-1',
        ComposerDraft(
          body: 'draft',
          replyTarget: null,
          attachments: const [],
          mentionUserIds: const [],
        ),
      );
      final oldEpoch = ComposerDraftMemory.epoch;
      ComposerDraftMemory.clear();
      expect(ComposerDraftMemory.epoch, oldEpoch + 1);
      expect(
        ComposerDraftMemory.load<ChatMessage>(
          'account-1',
          ComposerDraftKind.channel,
          'channel-1',
        ),
        isNull,
      );
      ComposerDraftMemory.save(
        'account-1',
        ComposerDraftKind.channel,
        'channel-1',
        ComposerDraft(
          body: '',
          replyTarget: null,
          attachments: const [],
          mentionUserIds: const [],
        ),
      );
      expect(
        ComposerDraftMemory.load<ChatMessage>(
          'account-1',
          ComposerDraftKind.channel,
          'channel-1',
        ),
        isNull,
      );
    },
  );
}

ChatMessage _message(String id) => ChatMessage(
  id: id,
  channelId: 'channel-1',
  authorId: 'account-2',
  body: 'target',
  createdAt: DateTime.utc(2026),
  deleted: false,
  revision: 1,
);
