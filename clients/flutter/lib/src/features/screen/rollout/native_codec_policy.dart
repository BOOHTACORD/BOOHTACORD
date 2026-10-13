/// Version-scoped, prevalidated profile compatibility, not an advertised codec
/// name or a hardware-encoder inference. Unknown includes missing observations.
enum NativeCodecSupport { supported, unknown, unsupported }

enum NativeCodecOutcome {
  requested,
  confirmed,
  negotiationMismatch,
  encodeFailure,
  publishFailure,
}

enum NativeCodecAction {
  keepBaseline,
  requestExperimental,
  continueConfirmed,
  suggestVp8Fallback,
  defer,
  stopUnsupported,
}

enum NativeCodecReason {
  cohortNotApproved,
  profileNotValidated,
  compatibleCohort,
  negotiatedProfileConfirmed,
  failedExperimentalPublication,
  fallbackNotValidated,
  fallbackBudgetExhausted,
}

class NativeCodecEvidence {
  NativeCodecEvidence({
    required this.senderProfile,
    required List<NativeCodecSupport> viewerProfiles,
    required this.sfuProfile,
    required this.vp8Fallback,
    this.measuredCohortApproved = false,
  }) : viewerProfiles = List.unmodifiable(viewerProfiles);

  final NativeCodecSupport senderProfile, sfuProfile, vp8Fallback;
  final List<NativeCodecSupport> viewerProfiles;

  /// Approval requires measured improvement and the documented device/profile
  /// envelope. Capability intersection alone cannot supply this approval.
  final bool measuredCohortApproved;
}

class NativeCodecDecision {
  const NativeCodecDecision(this.action, this.codec, this.reason);
  final NativeCodecAction action;
  final String? codec;
  final NativeCodecReason reason;
  bool get confirmed => action == NativeCodecAction.continueConfirmed;
  bool get hardwareProven => false;
}

/// No scheduler, publication or retry is performed here. A future caller must
/// route an explicit fallback suggestion through the serialized publisher
/// lifecycle with fresh generation/readback. One suggestion is the entire budget.
NativeCodecDecision decideNativeCodec({
  required NativeCodecEvidence evidence,
  NativeCodecOutcome outcome = NativeCodecOutcome.requested,
  int fallbackAttempts = 0,
}) {
  if (fallbackAttempts < 0) {
    return const NativeCodecDecision(
      NativeCodecAction.stopUnsupported,
      null,
      NativeCodecReason.fallbackBudgetExhausted,
    );
  }
  final failed =
      outcome == NativeCodecOutcome.negotiationMismatch ||
      outcome == NativeCodecOutcome.encodeFailure ||
      outcome == NativeCodecOutcome.publishFailure;
  if (failed) {
    if (fallbackAttempts >= 1) {
      return const NativeCodecDecision(
        NativeCodecAction.stopUnsupported,
        null,
        NativeCodecReason.fallbackBudgetExhausted,
      );
    }
    if (evidence.vp8Fallback != NativeCodecSupport.supported) {
      return const NativeCodecDecision(
        NativeCodecAction.stopUnsupported,
        null,
        NativeCodecReason.fallbackNotValidated,
      );
    }
    return const NativeCodecDecision(
      NativeCodecAction.suggestVp8Fallback,
      'vp8',
      NativeCodecReason.failedExperimentalPublication,
    );
  }
  final compatible =
      evidence.senderProfile == NativeCodecSupport.supported &&
      evidence.sfuProfile == NativeCodecSupport.supported &&
      evidence.viewerProfiles.isNotEmpty &&
      evidence.viewerProfiles.every((v) => v == NativeCodecSupport.supported);
  if (!evidence.measuredCohortApproved || !compatible) {
    final reason = !evidence.measuredCohortApproved
        ? NativeCodecReason.cohortNotApproved
        : NativeCodecReason.profileNotValidated;
    return NativeCodecDecision(
      evidence.vp8Fallback == NativeCodecSupport.supported
          ? NativeCodecAction.keepBaseline
          : NativeCodecAction.defer,
      evidence.vp8Fallback == NativeCodecSupport.supported ? 'vp8' : null,
      reason,
    );
  }
  return NativeCodecDecision(
    outcome == NativeCodecOutcome.confirmed
        ? NativeCodecAction.continueConfirmed
        : NativeCodecAction.requestExperimental,
    'h264',
    outcome == NativeCodecOutcome.confirmed
        ? NativeCodecReason.negotiatedProfileConfirmed
        : NativeCodecReason.compatibleCohort,
  );
}

/// Independent build-time request. No production H264 cohort is admitted yet;
/// every request retains the existing VP8 baseline. This is a signed-build
/// configuration, not a remote kill switch or a new viewer compatibility claim.
String nativeScreenDefaultCodec({
  String requestedCodec = const String.fromEnvironment(
    'BOOHTACORD_NATIVE_SCREEN_CODEC',
    defaultValue: 'vp8',
  ),
}) => 'vp8';
