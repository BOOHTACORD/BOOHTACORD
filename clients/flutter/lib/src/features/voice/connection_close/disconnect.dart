import 'package:livekit_client/livekit_client.dart'
    hide voiceReconnectAttemptLimit;

import '../../../services/voice_reconnect_policy.dart';
import '../lifecycle/controller.dart';

extension VoiceConnectionCloseDisconnect on VoiceController {
  Future<void> handleUnexpectedVoiceDisconnect(
    Room room,
    RoomDisconnectedEvent event,
  ) async {
    if (!identical(this.room, room) || voicePhase == VoicePhase.leaving) return;
    final channel = voiceChannel;
    final oldLease = leaseId;
    final restoreDeafen = deafened;
    final listen = listenerOnly ||
        (microphoneMuted && audioActivationMode != AudioActivationMode.ptt) ||
        restoreDeafen;
    final recoverable = channel != null &&
        disconnect.notice?.source != 'server' &&
        shouldRecoverVoiceDisconnect(event.reason);
    if (recoverable && oldLease != null) {
      voiceRecoveryReleasedLeases.add(oldLease);
    }
    final message = switch (event.reason) {
      DisconnectReason.duplicateIdentity =>
        'Голосовое подключение открыто в другом окне. Перенесите его оттуда.',
      DisconnectReason.participantRemoved =>
        'Администратор отключил вас от голосового канала.',
      DisconnectReason.roomDeleted => 'Голосовая комната была закрыта.',
      DisconnectReason.reconnectAttemptsExceeded =>
        'Не удалось восстановить голосовое соединение после $voiceReconnectAttemptLimit попыток. Подключитесь ещё раз.',
      _ => 'Связь с голосовым каналом потеряна. Подключитесь ещё раз.',
    };
    if (leaseId != null) disconnect.bind(leaseId!, voiceChannel?.id ?? '');
    if (!recoverable) disconnect.transport(message);
    final generation = disconnect.generation;
    final ticket = scope.capture();
    final closing = leaveVoice(explicit: false);
    final revision = operationRevision;
    screenThumbnails.clear();
    screenThumbnailPublications.clear();
    await closing;
    if (!active(ticket, revision) || generation != disconnect.generation) return;
    if (recoverable && disconnect.notice?.source != 'server') {
      recoverVoiceChannel(
        channel,
        previousLease: oldLease,
        listen: listen,
        restoreDeafen: restoreDeafen,
      );
      return;
    }
    showVoiceDisconnect();
  }
}
