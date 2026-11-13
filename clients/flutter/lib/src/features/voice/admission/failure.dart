import '../../../services/android_audio_devices.dart';
import '../../../services/voice_lease_revocation.dart';
import '../../../core/http/api_failure.dart';
import '../lifecycle/controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../telemetry/action_scope/failure.dart';

extension VoiceAdmissionFailure on VoiceController {
  Future<void> failVoiceAdmission(
    Object cause,
    String? admittedLease, {
    bool presentCause = true,
  }) async {
    stopVoiceConnectionStatsPolling();
    final revoked = revokedVoiceLeasesDuringJoin.remove(admittedLease);
    final failure = failureOutcome(cause);
    ActionScope.current?.finish(
      !presentCause
          ? 'superseded'
          : revoked != null || cause is VoiceLeaseRevocation
          ? 'rejected'
          : failure.outcome,
      reason: !presentCause
          ? 'generation_changed'
          : revoked != null || cause is VoiceLeaseRevocation
          ? 'revoked'
          : failure.reason,
    );
    if (presentCause && admittedLease != null && revoked != null) {
      disconnect.server(admittedLease, revoked);
    }
    if (presentCause &&
        admittedLease != null &&
        cause is VoiceLeaseRevocation) {
      disconnect.server(admittedLease, cause.reason);
    }
    final retryableRecovery =
        voiceRecoveryActive &&
        presentCause &&
        revoked == null &&
        disconnect.notice?.source != 'server' &&
        cause is! VoiceLeaseRevocation &&
        !(cause is ApiFailure &&
            const {401, 403, 404, 409}.contains(cause.status));
    error = !presentCause || retryableRecovery
        ? null
        : disconnect.notice?.message ??
              (revoked != null
                  ? VoiceLeaseRevocation(
                      leaseId: admittedLease!,
                      reason: revoked,
                    ).message
                  : cause is VoiceLeaseRevocation
                  ? cause.message
                  : formatError(cause));
    voicePhase = retryableRecovery
        ? VoicePhase.reconnecting
        : presentCause
        ? VoicePhase.error
        : VoicePhase.idle;
    room = null;
    leaseId = null;
    if (!retryableRecovery) voiceChannel = null;
    mutedScreenShareAudioIdentities.clear();
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
  }
}
