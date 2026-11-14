import 'dart:async';

import 'package:flutter/services.dart';

import '../roster_display/feed.dart';
import 'configuration.dart';

class WindowsVoiceOverlayClient {
  WindowsVoiceOverlayClient({required this.feed, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('boohtacord/voice_overlay') {
    configuration = OverlayConfigurationBridge(_channel);
    feed.addListener(_publish);
    unawaited(_publish());
  }

  final VoiceOverlayFeed feed;
  final MethodChannel _channel;
  late final OverlayConfigurationBridge configuration;
  Future<void> _tail = Future<void>.value();
  int _snapshotRevision = 0;

  Future<void> _publish() {
    final snapshot = feed.snapshot;
    final arguments = <String, Object>{
      'visible': snapshot.visible,
      'members': snapshot.members
          .map(
            (member) => <String, Object>{
              'displayName': member.displayName,
              'speaking': member.speaking,
              'microphoneMuted': member.microphoneMuted,
              'deafened': member.deafened,
            },
          )
          .toList(growable: false),
    };
    return _enqueue(arguments);
  }

  Future<void> dispose() {
    configuration.dispose();
    feed.removeListener(_publish);
    return _enqueue(const {'visible': false, 'members': <Object>[]});
  }

  Future<void> _enqueue(Map<String, Object> arguments) {
    final revision = ++_snapshotRevision;
    _tail = _tail.then((_) async {
      if (revision != _snapshotRevision) return;
      try {
        await _channel.invokeMethod<void>('setSnapshot', arguments);
      } on MissingPluginException {
        // The Windows runner owns this channel; keep the client UI independent.
      } on PlatformException {
        // A native overlay failure must not interrupt the voice session.
      }
    });
    return _tail;
  }
}
