import 'dart:async';

import '../lifecycle/controller.dart';
import 'audio_publication.dart';
import 'discovery.dart';
import 'publication_generation.dart';
import 'transition.dart';
import '../../telemetry/observe_render/view.dart';
import '../screen_viewer_presence/identity.dart';

extension VoiceScreenViewerSelection on VoiceController {
  void markRemoteScreenFirstFrameRendered(
    String identity,
    String publicationSid,
  ) {
    final generation = selectedRemoteScreenViewerGeneration;
    if (generation?.participantIdentity != identity ||
        generation?.publicationSid != publicationSid) {
      return;
    }
    remoteScreenViewerRecoveryTimer?.cancel();
    remoteScreenViewerRecoveryTimer = null;
    remoteScreenViewerRecoveryDeadline.reset();
    remoteScreenViewerRecoveryAttempt = 0;
    remoteScreenViewerRecoveryInFlightGeneration = null;
    remoteScreenViewerRecoveryPublication = null;
    remoteScreenViewerRecoveryIsCurrent = null;
    remoteScreenViewerFirstFrameGeneration = generation;
  }

  Future<void> selectRemoteScreenForViewing(String? participantIdentity) async {
    final ticket = scope.capture();
    final operationRevision = this.operationRevision;
    if (!active(ticket, operationRevision)) return;
    final normalized = participantIdentity?.trim();
    final nextIdentity = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    final room = this.room;
    final nextParticipant = nextIdentity == null
        ? null
        : room?.remoteParticipants[nextIdentity];
    final nextPublication = nextParticipant == null
        ? null
        : firstDiscoverableRemoteScreenPublication(nextParticipant);
    final nextAudioPublication = nextParticipant == null
        ? null
        : screenShareAudioPublication(nextParticipant);
    final nextGeneration = nextPublication == null || nextIdentity == null
        ? null
        : ScreenViewerPublicationGeneration(
            participantIdentity: nextIdentity,
            publicationSid: nextPublication.sid,
          );
    final previousIdentity = selectedRemoteScreenViewerIdentity;
    final previousGeneration = selectedRemoteScreenViewerGeneration;
    final previousPublication = selectedRemoteScreenViewerPublication;
    final previousAudioPublication = selectedRemoteScreenViewerAudioPublication;
    if (previousIdentity == nextIdentity &&
        previousGeneration == nextGeneration &&
        previousAudioPublication?.sid == nextAudioPublication?.sid) {
      selectedRemoteScreenViewerPublication = nextPublication;
      selectedRemoteScreenViewerAudioPublication = nextAudioPublication;
      return;
    }

    if (previousGeneration != nextGeneration) {
      remoteScreenViewerRecoveryTimer?.cancel();
      remoteScreenViewerRecoveryTimer = null;
      remoteScreenViewerRecoveryDeadline.reset();
      remoteScreenViewerRecoveryAttempt = 0;
      remoteScreenViewerRecoveryInFlightGeneration = null;
      remoteScreenViewerRecoveryPublication = null;
      remoteScreenViewerRecoveryIsCurrent = null;
      remoteScreenViewerFirstFrameGeneration = null;
    }

    if (previousIdentity != nextIdentity) {
      if (nextIdentity == null) {
        stopView(api.transport.session.telemetry);
      } else {
        beginView(api.transport.session.telemetry);
      }
    }
    final previousRevision = screenViewerSelectionRevision;
    selectedRemoteScreenViewerIdentity = nextIdentity;
    if (screenViewerSelectionRevision == previousRevision) {
      screenViewerSelectionRevision++;
    }
    final selectionRevision = screenViewerSelectionRevision;
    selectedRemoteScreenViewerGeneration = nextGeneration;
    selectedRemoteScreenViewerPublication = nextPublication;
    selectedRemoteScreenViewerAudioPublication = nextAudioPublication;
    unawaited(
      screenViewerPresence.selectAudience(
        leaseId,
        voiceLeaseIdFromLiveKitIdentity(nextIdentity),
      ),
    );
    queueRemoteScreenSubscriptionTransition(
      this,
      previousPublication: previousPublication,
      previousAudioPublication: previousAudioPublication,
      nextPublication: nextPublication,
      nextAudioPublication: nextAudioPublication,
      isCurrent: () =>
          active(ticket, operationRevision) &&
          selectionRevision == screenViewerSelectionRevision,
    );
  }
}
