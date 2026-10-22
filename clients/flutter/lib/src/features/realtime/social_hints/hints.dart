import 'dart:async';

import '../../../core/http/transport.dart';
import '../../../core/session/scope.dart';
import '../../conversation/reactions/model.dart';
import '../lifecycle/event.dart';

class SocialHint {
  const SocialHint(this.direct, this.conversation, this.message, this.pins);
  final bool direct, pins;
  final String conversation, message;
}

class SocialObserver {
  SocialObserver(this.ticket, this.server, this.listener);
  final SessionTicket ticket;
  final int server;
  final FutureOr<void> Function(SocialHint?) listener;
}

class SocialHints {
  SocialHints(this.transport);
  final ApiTransport transport;
  static final _owners = Expando<SocialHints>();
  static SocialHints forTransport(ApiTransport transport) =>
      _owners[transport] ??= SocialHints(transport);
  final _observers = <SocialObserver>{};
  int get observerCount => _observers.length;
  void Function() subscribe(FutureOr<void> Function(SocialHint?) listener) {
    final observer = SocialObserver(
      transport.session.scope.capture(),
      transport.session.serverRevision,
      listener,
    );
    _observers.add(observer);
    return () => _observers.remove(observer);
  }

  void emit(SocialHint? hint) {
    for (final observer in _observers.toList()) {
      if (!observer.ticket.isActive ||
          observer.server != transport.session.serverRevision) {
        _observers.remove(observer);
        continue;
      }
      try {
        unawaited(
          Future<void>.sync(() => observer.listener(hint))
              .catchError((Object _) {}),
        );
      } catch (_) {
        /* Disposed observer must not interrupt session delivery. */
      }
    }
  }

  Future<bool> receiveAsync(RealtimeEvent event) async {
    final recovery =
        event.kind == 'connection.ready' ||
        event.kind == 'connection.resync_required';
    if (!recovery &&
        ![
          'message.reactions_updated',
          'message.pins_updated',
          'direct_message.reactions_updated',
        ].contains(event.kind))
      return false;
    final direct = event.kind == 'direct_message.reactions_updated';
    final payload = event.payload;
    SocialHint? hint;
    if (!recovery) {
      final conversation = payload[direct ? 'direct_message_id' : 'channel_id'],
          message = payload['message_id'];
      if (payload.length != 2 ||
          !socialUuid(conversation) ||
          !socialUuid(message))
        throw const FormatException('Invalid social hint');
      hint = SocialHint(
        direct,
        conversation as String,
        message as String,
        event.kind == 'message.pins_updated',
      );
    }
    await Future.wait(
      _observers.toList().map((observer) async {
        if (!observer.ticket.isActive ||
            observer.server != transport.session.serverRevision) {
          _observers.remove(observer);
          return;
        }
        await observer.listener(hint);
      }),
    );
    return !recovery;
  }

  bool receive(RealtimeEvent event) {
    if (event.kind == 'connection.ready' ||
        event.kind == 'connection.resync_required') {
      emit(null);
      return false;
    }
    if (![
      'message.reactions_updated',
      'message.pins_updated',
      'direct_message.reactions_updated',
    ].contains(event.kind)) {
      return false;
    }
    final direct = event.kind == 'direct_message.reactions_updated',
        payload = event.payload;
    final conversation = payload[direct ? 'direct_message_id' : 'channel_id'],
        message = payload['message_id'];
    if (payload.length == 2 &&
        socialUuid(conversation) &&
        socialUuid(message)) {
      emit(
        SocialHint(
          direct,
          conversation as String,
          message as String,
          event.kind == 'message.pins_updated',
        ),
      );
    }
    return true;
  }
}
