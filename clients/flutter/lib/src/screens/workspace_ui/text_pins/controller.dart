import 'package:flutter/foundation.dart';

import '../../../core/http/transport.dart';
import '../../../core/session/scope.dart';
import '../../../features/conversation/pins/api.dart';
import '../../../features/conversation/pins/model.dart';
import '../../../features/realtime/social_hints/hints.dart';

class TextPinsController extends ChangeNotifier {
  TextPinsController(this.transport, this.channel)
    : ticket = transport.session.scope.capture(),
      server = transport.session.serverRevision {
    stop = SocialHints.forTransport(transport).subscribe((hint) {
      if (hint == null ||
          !hint.direct && hint.pins && hint.conversation == channel) {
        return load(strict: true);
      }
    });
  }
  final ApiTransport transport;
  final String channel;
  final SessionTicket ticket;
  final int server;
  late final void Function() stop;
  List<TextPin> pins = [];
  String? cursor, error;
  bool canManage = false, loading = false, busy = false, disposed = false;
  int sequence = 0;
  bool get active =>
      !disposed &&
      ticket.isActive &&
      server == transport.session.serverRevision;
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> load({bool more = false, bool strict = false}) async {
    if (!active) return;
    final own = ++sequence, previous = cursor;
    loading = true;
    error = null;
    if (!more) {
      pins = [];
      cursor = null;
      canManage = false;
    }
    changed();
    try {
      final page = await TextPinApi(transport)
          .read(channel, before: more ? previous : null);
      if (!active || own != sequence) return;
      pins = more ? [...pins, ...page.pins] : page.pins;
      cursor = page.nextCursor;
      canManage = page.canManage;
    } catch (cause) {
      if (strict) rethrow;
      if (active && own == sequence) {
        pins = [];
        cursor = null;
        canManage = false;
        error = cause.toString();
      }
    } finally {
      if (active && own == sequence) {
        loading = false;
        changed();
      }
    }
  }

  Future<void> remove(String message) async {
    if (!active || busy || !canManage) return;
    busy = true;
    error = null;
    changed();
    try {
      await TextPinApi(transport).set(channel, message, false);
      if (active) {
        SocialHints.forTransport(transport)
            .emit(SocialHint(false, channel, message, true));
      }
    } catch (cause) {
      if (active) error = cause.toString();
    } finally {
      if (active) {
        busy = false;
        changed();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    sequence++;
    pins = [];
    stop();
    super.dispose();
  }
}
