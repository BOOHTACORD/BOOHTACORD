bool screenViewerMiniPlayerVisible({
  required String? selectedScreenIdentity,
  required String? activeVoiceChannelId,
  required String? selectedChannelId,
  required bool directMessageOpen,
  required bool workspacePanelOpen,
}) {
  if (selectedScreenIdentity == null ||
      selectedScreenIdentity.isEmpty ||
      activeVoiceChannelId == null) {
    return false;
  }
  return directMessageOpen ||
      workspacePanelOpen ||
      selectedChannelId != activeVoiceChannelId;
}

bool screenSelectionBelongsToVoiceChannel({
  required String? selectionVoiceChannelId,
  required String? activeVoiceChannelId,
}) =>
    selectionVoiceChannelId != null &&
    selectionVoiceChannelId == activeVoiceChannelId;

bool localScreenShareJustStarted({
  required bool wasSharing,
  required bool isSharing,
}) => !wasSharing && isSharing;

bool pinnedScreenPublicationEnded({
  required bool participantPresent,
  required bool publicationPresent,
}) => !participantPresent || !publicationPresent;
