import 'dart:async';

import '../../../models.dart';
import '../../../core/session/scope.dart';
import '../../../services/voice_volume_preferences.dart';
import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';

class CancelledVoiceAdmission implements Exception {}

extension VoiceAdmissionPrepare on VoiceController {
  void checkAdmission(SessionTicket ticket, int revision, String lease) {
    if (!active(ticket, revision)) throw CancelledVoiceAdmission();
    final reason = revokedVoiceLeasesDuringJoin[lease];
    if (reason != null) {
      throw VoiceLeaseRevocation(leaseId: lease, reason: reason);
    }
  }

  Future<void> loadVoiceVolumes(
    SessionTicket ticket,
    int revision,
    String lease,
  ) async {
    final account = readUser();
    if (account == null) return;
    await flushVoiceVolumes();
    checkAdmission(ticket, revision, lease);
    final preferences = await VoiceVolumePreferences.open(
      account.accountId,
      origin: api.baseUrl,
    );
    checkAdmission(ticket, revision, lease);
    if (readUser()?.accountId != account.accountId ||
        !preferences.belongsTo(account.accountId, api.baseUrl))
      throw CancelledVoiceAdmission();
    voiceVolumePreferences = preferences;
    volumePreferenceOutcome(preferences.status);
  }

  ({int revision, int disconnectGeneration})? prepareVoiceAdmission(
    GuildChannel channel,
    SessionTicket ticket,
    int admittedRevision,
  ) {
    if (!active(ticket, admittedRevision) ||
        channel.admissionClosed ||
        voiceAdmissionPending ||
        (voiceChannel?.id == channel.id && room != null)) {
      return null;
    }
    disconnect.selectChannel(channel.id);
    if (disconnect.notice?.reconnectAllowed == false) return null;
    disconnect.reset();
    revokedVoiceLeasesDuringJoin.clear();
    disconnect.channelId = channel.id;
    final disconnectGeneration = disconnect.generation;
    final revision = ++operationRevision;
    unawaited(screenViewerPresence.clear());
    clearScreenPreviewReceivers();
    screenThumbnails.clear();
    screenThumbnailPublications.clear();
    selectedRemoteScreenViewerIdentity = null;
    transientScreenShareVolumes.clear();
    voicePhase = VoicePhase.joining;
    voicePingMs = null;
    voiceAdmissionPending = true;
    microphoneUnavailable = false;
    error = null;
    notifyListeners();
    return (revision: revision, disconnectGeneration: disconnectGeneration);
  }
}
