import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceVoiceParticipantCard extends WorkspaceVoiceParticipantCardContext
    with WorkspaceVoiceParticipantCardBuildBinding {
  const WorkspaceVoiceParticipantCard({
    super.key,
    required super.state,
    required super.name,
    required super.avatarUrl,
    required super.muted,
    required super.speaking,
    super.volume,
    super.onVolumeChanged,
    super.hasScreen = false,
    super.watchingScreen = false,
    super.isLocal = false,
    super.onScreenTap,
    super.microphoneUnavailable = false,
    super.deafened = false,
  });
}
