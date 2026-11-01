import '../voice_avatar_color/component.dart';
import '../native_bindings.dart';

class WorkspaceVoiceNavigationMemberRow extends StatelessWidget {
  const WorkspaceVoiceNavigationMemberRow({
    super.key,
    required this.state,
    required this.name,
    required this.accountId,
    required this.muted,
    required this.speaking,
    required this.screenSharing,
    this.microphoneUnavailable = false,
    this.deafened = false,
  });

  final AppState state;
  final String name;
  final String? accountId;
  final bool muted;
  final bool microphoneUnavailable;
  final bool deafened;
  final bool speaking;
  final bool screenSharing;

  @override
  Widget build(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    final member = accountId == null
        ? null
        : state.members.where((item) => item.id == accountId).firstOrNull;
    return SizedBox(
      height: GcLayout.voiceMemberRowHeight,
      child: Row(
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: member?.avatarUrl,
            radius: 12,
            backgroundColor: workspaceVoiceAvatarColor(accountId ?? name),
            fallbackText: _voiceNavigationInitials(name),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: presentation.isSpeaking
                    ? GcColors.success
                    : GcColors.textSecondary,
                fontSize: 12,
                fontWeight: presentation.isSpeaking
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
          if (screenSharing)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Tooltip(
                message: 'Показывает экран',
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 16,
                  color: GcColors.accentText,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: presentation.label,
              child: Icon(
                deafened
                    ? Icons.headset_off
                    : presentation.isSpeaking
                    ? Icons.graphic_eq
                    : muted || microphoneUnavailable
                    ? Icons.mic_off_outlined
                    : Icons.mic_none,
                size: 16,
                color: deafened
                    ? GcColors.danger
                    : microphoneUnavailable
                    ? GcColors.warning
                    : muted
                    ? GcColors.muted
                    : GcColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _voiceNavigationInitials(String name) {
  final letters = RegExp(r'\p{L}', unicode: true);
  final initials = name.runes
      .map(String.fromCharCode)
      .where((letter) => letters.hasMatch(letter))
      .take(2)
      .join();
  return initials.isEmpty ? 'У' : initials.toUpperCase();
}
