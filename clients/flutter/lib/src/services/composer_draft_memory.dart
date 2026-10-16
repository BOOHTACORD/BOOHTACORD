import '../models.dart';

enum ComposerDraftKind { channel, directMessage }

class ComposerDraft<TReply> {
  const ComposerDraft({
    required this.body,
    required this.replyTarget,
    required this.attachments,
    required this.mentionUserIds,
    this.pendingReplyId,
  });

  final String? pendingReplyId;
  final String body;
  final TReply? replyTarget;
  final List<MessageAttachment> attachments;
  final List<String> mentionUserIds;
}

/// Holds unsent composer state while the authenticated workspace stays open.
/// Drafts are scoped by account, conversation type, and conversation ID.
abstract final class ComposerDraftMemory {
  static final Map<String, ComposerDraft<Object?>> _drafts = {};
  static int _epoch = 0;
  static int revision = 0;
  static final Map<String, int> _edits = {};
  static void Function()? changed;

  static List<Map<String, dynamic>> exportForAccount(String account) => [
    for (final entry in _drafts.entries)
      if (entry.key.startsWith('$account\u0000'))
        {
          'kind': entry.key.split('\u0000')[1],
          'conversation': entry.key.split('\u0000')[2],
          'body': entry.value.body,
          'mentions': entry.value.mentionUserIds,
          'attachments': [
            for (final a in entry.value.attachments)
              {
                'id': a.id,
                'original_name': a.originalName,
                'byte_size': a.sizeBytes,
              },
          ],
          'reply_id': switch (entry.value.replyTarget) {
            ChatMessage m => m.id,
            DirectChatMessage m => m.id,
            _ => entry.value.pendingReplyId,
          },
        },
  ];

  static void importForAccount(
    String account,
    List<dynamic> values, {
    Map<String, Object> replies = const {},
    int? unchangedSince,
  }) {
    _epoch++;
    for (final raw in values.take(100)) {
      if (raw is! Map ||
          raw['body'] is! String ||
          (raw['body'] as String).length > 25000 ||
          raw['conversation'] is! String)
        continue;
      final kind = raw['kind'] == 'directMessage'
          ? ComposerDraftKind.directMessage
          : ComposerDraftKind.channel;
      final key = _key(account, kind, raw['conversation'] as String);
      if (unchangedSince != null && (_edits[key] ?? 0) > unchangedSince)
        continue;
      final reply = replies[raw['reply_id']];
      final draft = ComposerDraft<Object?>(
        body: raw['body'] as String,
        replyTarget: reply,
        pendingReplyId: reply == null ? raw['reply_id'] as String? : null,
        attachments: parseMessageAttachments(raw['attachments']),
        mentionUserIds: (raw['mentions'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
      _drafts[key] = draft;
    }
  }

  static int get epoch => _epoch;

  static String _key(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
  ) => '$accountId\u0000${kind.name}\u0000$conversationId';

  static ComposerDraft<TReply>? load<TReply>(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
  ) {
    final draft = _drafts[_key(accountId, kind, conversationId)];
    if (draft == null) return null;
    return ComposerDraft<TReply>(
      body: draft.body,
      pendingReplyId: draft.pendingReplyId,
      replyTarget: draft.replyTarget as TReply?,
      attachments: List.unmodifiable(draft.attachments),
      mentionUserIds: List.unmodifiable(draft.mentionUserIds),
    );
  }

  static void save<TReply>(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
    ComposerDraft<TReply> draft,
  ) {
    final key = _key(accountId, kind, conversationId);
    _edits[key] = ++revision;
    if (draft.body.isEmpty &&
        draft.replyTarget == null &&
        draft.attachments.isEmpty &&
        draft.mentionUserIds.isEmpty) {
      _drafts.remove(key);
      changed?.call();
      return;
    }
    _drafts[key] = ComposerDraft<Object?>(
      body: draft.body,
      pendingReplyId: draft.pendingReplyId,
      replyTarget: draft.replyTarget,
      attachments: List.unmodifiable(draft.attachments),
      mentionUserIds: List.unmodifiable(draft.mentionUserIds),
    );
    changed?.call();
  }

  static void clear() {
    _epoch++;
    _drafts.clear();
    _edits.clear();
    revision++;
  }
}
