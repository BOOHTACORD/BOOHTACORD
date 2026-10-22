import 'package:flutter/foundation.dart';

import '../../../core/http/transport.dart';
import '../../../core/session/scope.dart';
import '../../../features/conversation/reactions/batch.dart';
import '../../../features/conversation/reactions/model.dart';
import '../../../features/realtime/social_hints/hints.dart';

class MessageSocialController extends ChangeNotifier {
  MessageSocialController(
    this.transport,
    this.direct,
    this.conversation,
    this.message,
  ) : ticket = transport.session.scope.capture(),
      server = transport.session.serverRevision {
    stop = SocialHints.forTransport(transport).subscribe((hint) {
      if (hint == null ||
          hint.direct == direct &&
              hint.conversation == conversation &&
              hint.message == message) {
        return load(strict: true);
      }
    });
  }
  final ApiTransport transport;
  final bool direct;
  final String conversation, message;
  final SessionTicket ticket;
  final int server;
  late final void Function() stop;
  int sequence = 0;
  bool disposed = false, loading = false, busy = false, canPin = false;
  String? error, notice;
  List<MessageReaction> rows = [];
  bool get active =>
      !disposed &&
      ticket.isActive &&
      server == transport.session.serverRevision;
  bool mine(String emoji) => rows.any((row) => row.emoji == emoji && row.mine);
  int count(String emoji) =>
      rows.where((row) => row.emoji == emoji).firstOrNull?.count ?? 0;
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> load({bool strict = false}) async {
    if (!active) return;
    final own = ++sequence;
    loading = true;
    error = null;
    changed();
    try {
      final page = await ReactionBatch.forTransport(transport)
          .read(direct, conversation, message);
      if (!active || own != sequence) return;
      rows = page.rows;
      canPin = page.canPin;
    } catch (cause) {
      if (strict) rethrow;
      if (active && own == sequence) {
        rows = [];
        canPin = false;
        error = cause.toString();
      }
    } finally {
      if (active && own == sequence) {
        loading = false;
        changed();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    sequence++;
    rows = [];
    stop();
    super.dispose();
  }
}
