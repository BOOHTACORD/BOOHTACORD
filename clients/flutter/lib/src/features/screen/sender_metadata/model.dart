class ScreenShareSenderDescriptor {
  const ScreenShareSenderDescriptor({
    required this.originId,
    required this.accountId,
    required this.roomId,
    required this.mediaSessionId,
    required this.publicationGeneration,
    required this.operationRevision,
    required this.mode,
    required this.requestedProfileId,
    this.effectiveProfile,
    this.publisherState,
    this.viewerState,
    this.layerTopology,
    this.profileRevision,
    this.reasonCodes = const [],
  });

  final String originId;
  final String accountId;
  final String roomId;
  final String mediaSessionId;
  final int publicationGeneration;
  final int operationRevision;
  final String mode;
  final String requestedProfileId;
  final Map<String, Object?>? effectiveProfile;
  final String? publisherState, viewerState, layerTopology;
  final int? profileRevision;
  final List<String> reasonCodes;
}
