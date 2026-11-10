import 'dart:async';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/models.dart';
export 'package:boohtacord_desktop/src/services/api_client.dart'
    show ApiFailure;

const channel = GuildChannel(
  id: 'voice',
  name: 'Voice',
  kind: ChannelKind.voice,
  admissionClosed: false,
);
const credential = VoiceCredential(
  url: 'wss://voice.invalid',
  token: 'test-only',
);

class DelayedVoiceApi extends ApiClient {
  @override
  bool get realtimeEnabled => false;

  final credential = Completer<(String, VoiceCredential)>();
  final requestedVoiceTransfers = <bool>[];
  Future<void> Function(String)? onRelease;
  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) {
    requestedVoiceTransfers.add(transfer);
    return credential.future;
  }
  @override
  Future<void> logout() async {}
  @override
  Future<void> releaseVoice(String leaseId) async {
    await onRelease?.call(leaseId);
  }
}
