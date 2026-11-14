import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';

extension VoiceLeaseEventsRevocation on VoiceController {
  Future<void> dispatchVoiceRevocation(Map<String, dynamic> payload, {Future<void> Function(String)? moveToAfk}) async {
    if (disposed || !scope.capture().isActive) return;
    if (payload['reason'] == 'VOLUNTARY_LEAVE' &&
        voiceRecoveryReleasedLeases.contains(payload['lease_id'])) {
      return;
    }
    final revocation = VoiceLeaseRevocation.parse(
      payload['lease_id'],
      payload['reason'],
      activeLeaseId: leaseId ?? disconnect.leaseId,
      admissionPending: voiceAdmissionPending,
    );
    if (revocation == null) return;
    if (leaseId == revocation.leaseId) {
      disconnect.bind(
        revocation.leaseId,
        voiceChannel?.id ?? disconnect.channelId ?? '',
      );
    }
    final accepted = disconnect.server(revocation.leaseId, revocation.reason);
    final wasRecovering = voiceRecoveryActive;
    if (accepted) cancelVoiceRecovery();
    if (accepted && room == null && !voiceAdmissionPending) {
      if (wasRecovering) voiceChannel = null;
      showVoiceDisconnect();
      final target = payload['target_channel_id'];
      if (revocation.reason == 'AFK_MOVE' && target is String) await moveToAfk?.call(target);
      return;
    }
    if (voiceAdmissionPending) {
      revokedVoiceLeasesDuringJoin[revocation.leaseId] = revocation.reason;
      if (revokedVoiceLeasesDuringJoin.length > 16) {
        revokedVoiceLeasesDuringJoin.remove(
          revokedVoiceLeasesDuringJoin.keys.first,
        );
      }
      if (leaseId == revocation.leaseId) {
        await pendingRoom?.disconnect().catchError((Object _) {});
      }
    } else {
      await handleVoiceLeaseRevoked(revocation.leaseId, revocation.reason);
      final target = payload['target_channel_id'];
      if (accepted && revocation.reason == 'AFK_MOVE' && target is String) await moveToAfk?.call(target);
    }
  }

  Future<void> handleVoiceLeaseRevoked(String leaseId, String reason) async {
    if (this.leaseId != leaseId || room == null) return;
    disconnect.bind(leaseId, voiceChannel?.id ?? disconnect.channelId ?? '');
    disconnect.server(leaseId, reason);
    cancelVoiceRecovery();
    final generation = disconnect.generation;
    final ticket = scope.capture();
    final closing = leaveVoice(explicit: false);
    final revision = operationRevision;
    await closing;
    if (!active(ticket, revision) || generation != disconnect.generation) {
      return;
    }
    showVoiceDisconnect();
  }
}
