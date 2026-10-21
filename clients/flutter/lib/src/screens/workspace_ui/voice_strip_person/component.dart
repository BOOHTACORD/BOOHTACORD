import '../native_bindings.dart';

class WorkspaceVoiceStripPerson extends StatelessWidget {
  const WorkspaceVoiceStripPerson({
    super.key,
    required this.state,
    required this.name,
    required this.avatarUrl,
    required this.muted,
    required this.speaking,
    this.microphoneUnavailable = false,
    this.deafened = false,
    this.screenSharing = false,
    this.watchingScreen = false,
    this.watcherLabel = 'Смотрит трансляцию',
  });

  final AppState state;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool speaking;
  final bool microphoneUnavailable;
  final bool deafened;
  final bool screenSharing;
  final bool watchingScreen;
  final String watcherLabel;

  @override
  Widget build(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: presentation.isSpeaking ? GcColors.success : GcColors.border,
        ),
      ),
      child: Row(
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: avatarUrl,
            radius: 15,
            borderColor: presentation.isSpeaking ? GcColors.success : null,
            borderWidth: presentation.isSpeaking ? 2 : 0,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (screenSharing) const VoiceStreamIndicator(),
          if (watchingScreen)
            Tooltip(
              message: watcherLabel,
              child: const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: GcColors.accentText,
              ),
            ),
          Tooltip(
            message: presentation.label,
            child: Icon(
              deafened
                  ? Icons.headset_off
                  : muted || microphoneUnavailable
                  ? Icons.mic_off
                  : presentation.isSpeaking
                  ? Icons.graphic_eq
                  : Icons.mic,
              size: 15,
              color: deafened
                  ? GcColors.danger
                  : microphoneUnavailable
                  ? GcColors.warning
                  : muted
                  ? GcColors.danger
                  : GcColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
