import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/session/scope.dart';
import '../../models.dart';

/// Owns the lifetime of already loaded bytes, independently of the source row
/// and its dialog route. Eviction alone is not evidence of message deletion.
class RevocableAttachmentView extends StatefulWidget {
  const RevocableAttachmentView({
    super.key,
    required this.state,
    required this.parentPath,
    required this.attachmentId,
    required this.child,
    this.messageId,
  });
  final AppState state;
  final String parentPath, attachmentId;
  final String? messageId;
  final Widget child;
  @override
  State<RevocableAttachmentView> createState() => _RevocableAttachmentState();
}

class _RevocableAttachmentState extends State<RevocableAttachmentView> {
  late final SessionTicket _ticket;
  late final int _server;
  String? _messageId;
  bool _revoked = false;
  Iterable<({String id, bool deleted, List<MessageAttachment> attachments})>
  get _rows sync* {
    for (final row in widget.state.messages) {
      if (widget.parentPath ==
          '/channels/${Uri.encodeComponent(row.channelId)}') {
        yield (id: row.id, deleted: row.deleted, attachments: row.attachments);
      }
    }
    for (final row in widget.state.directMessageHistory) {
      if (widget.parentPath ==
          '/direct-messages/${Uri.encodeComponent(row.directMessageId)}') {
        yield (id: row.id, deleted: row.deleted, attachments: row.attachments);
      }
    }
  }

  bool get _invalid {
    if (widget.state.disposed ||
        !_ticket.isActive ||
        _server != widget.state.api.transport.session.serverRevision) {
      return true;
    }
    final row = _rows.where((row) => row.id == _messageId).firstOrNull;
    return row != null &&
        (row.deleted ||
            !row.attachments.any((file) => file.id == widget.attachmentId));
  }

  @override
  void initState() {
    super.initState();
    _ticket = widget.state.api.transport.session.scope.capture();
    _server = widget.state.api.transport.session.serverRevision;
    _messageId =
        widget.messageId ??
        _rows
            .where(
              (row) =>
                  row.attachments.any((file) => file.id == widget.attachmentId),
            )
            .firstOrNull
            ?.id;
    _revoked = _invalid;
    widget.state.addListener(_changed);
  }

  void _changed() {
    if (!_revoked && _invalid && mounted) setState(() => _revoked = true);
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_revoked
      ? widget.child
      : Dialog.fullscreen(
          key: const ValueKey('revoked-attachment-viewer'),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: 'Закрыть просмотр изображения',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: const Text('Вложение удалено или недоступно.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}
