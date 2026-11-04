import 'dart:async';
import '../../../core/http/api_failure.dart';
import '../../../models.dart';
import '../../../services/voice_reconnect_policy.dart';
import '../lifecycle/controller.dart';

extension VoiceAutomaticRecovery on VoiceController {
  void cancelVoiceRecovery({bool retainReleasedLeases = false}) {
    voiceRecoveryGeneration++;
    voiceRecoveryTimer?.cancel();
    voiceRecoveryTimer = null;
    voiceRecoveryActive = false;
    if (!retainReleasedLeases) voiceRecoveryReleasedLeases.clear();
  }
  /// Retry only while the original account and voluntary channel intent exist.
  /// Each attempt uses the normal API path (ACL + fresh JWT), never transfer.
  void recoverVoiceChannel(
    GuildChannel channel, {
    required String? previousLease,
    required bool listen,
    required bool restoreDeafen,
  }) {
    cancelVoiceRecovery(retainReleasedLeases: true);
    final user = readUser();
    if (disposed || user == null || channel.admissionClosed) {
      voiceRecoveryReleasedLeases.clear();
      return;
    }

    voiceRecoveryActive = true;
    final generation = voiceRecoveryGeneration;
    final ticket = scope.capture();
    final accountId = user.accountId;
    var failures = 0;
    var previousLeaseReleased = previousLease == null;

    bool current() =>
        voiceRecoveryActive &&
        !disposed &&
        voiceRecoveryGeneration == generation &&
        ticket.isActive &&
        readUser()?.accountId == accountId &&
        disconnect.notice?.source != 'server';

    void stop(String message) {
      if (!current()) return;
      cancelVoiceRecovery();
      voiceChannel = null;
      voicePhase = VoicePhase.error;
      error = message;
      notifyListeners();
    }

    Future<void> attempt() async {
      if (!current()) return;
      voiceRecoveryTimer = null;
      if (channel.admissionClosed) {
        stop('Голосовой канал больше не доступен.');
        return;
      }
      if (!previousLeaseReleased && previousLease != null) {
        try {
          await api.releaseVoice(previousLease);
          previousLeaseReleased = true;
        } catch (cause) {
          if (cause is ApiFailure && cause.status == 404) {
            previousLeaseReleased = true;
          } else if (cause is ApiFailure &&
              (cause.status == 401 || cause.status == 403 || cause.status == 409)) {
            stop('Восстановление остановлено: доступ к голосовому каналу изменился.');
            return;
          }
        }
      }
      if (!current()) return;
      if (previousLeaseReleased) {
        await admitVoice(channel, listenerOnly: listen, transfer: false);
        if (!current()) return;
        if (room != null &&
            voiceChannel?.id == channel.id &&
            (voicePhase == VoicePhase.connected ||
                voicePhase == VoicePhase.listener)) {
          cancelVoiceRecovery();
          if (restoreDeafen && !deafened) await toggleDeafen();
          error = null;
          notifyListeners();
          return;
        }
        final failure = lastVoiceAdmissionFailure;
        if (failure is ApiFailure &&
            (failure.status == 401 ||
                failure.status == 403 ||
                failure.status == 404 ||
                failure.status == 409)) {
          stop('Автоматическое восстановление остановлено: канал или сессия недоступны.');
          return;
        }
      }
      if (!current()) return;
      voiceChannel = channel;
      voicePhase = VoicePhase.reconnecting;
      error = null;
      notifyListeners();
      voiceRecoveryTimer = Timer(
        voiceLongRecoveryDelay(failures++),
        () => unawaited(attempt()),
      );
    }

    disconnect.clearTransportForRecovery();
    voiceChannel = channel;
    voicePhase = VoicePhase.reconnecting;
    error = null;
    notifyListeners();
    voiceRecoveryTimer = Timer(
      const Duration(seconds: 1),
      () => unawaited(attempt()),
    );
  }
}
