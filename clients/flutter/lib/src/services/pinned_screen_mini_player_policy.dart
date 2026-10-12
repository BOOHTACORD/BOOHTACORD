bool pinnedScreenMiniPlayerVisible({
  required String? pinnedScreenIdentity,
  required String? activeVoiceChannelId,
  required String? selectedChannelId,
  required bool directMessageOpen,
  required bool workspacePanelOpen,
}) {
  if (pinnedScreenIdentity == null || activeVoiceChannelId == null) {
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

/// A hidden, unpinned viewer must stop, including pending source restarts.
bool unpinnedScreenSelectionShouldStop({
  required String? selectedScreenIdentity,
  required String? waitingScreenIdentity,
  required String? pinnedScreenIdentity,
  required String? activeVoiceChannelId,
  required String? selectedChannelId,
  required bool directMessageOpen,
  required bool workspacePanelOpen,
}) {
  final hasSelection =
      (selectedScreenIdentity?.isNotEmpty ?? false) ||
      (waitingScreenIdentity?.isNotEmpty ?? false);
  final viewingActiveVoice =
      activeVoiceChannelId != null &&
      selectedChannelId == activeVoiceChannelId &&
      !directMessageOpen &&
      !workspacePanelOpen;
  return hasSelection &&
      pinnedScreenIdentity == null &&
      activeVoiceChannelId != null &&
      !viewingActiveVoice;
}
