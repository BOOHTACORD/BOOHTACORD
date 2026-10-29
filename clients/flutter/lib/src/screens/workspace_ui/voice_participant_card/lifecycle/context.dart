import '../../native_bindings.dart';

abstract class WorkspaceVoiceParticipantCardContext extends StatelessWidget {
  const WorkspaceVoiceParticipantCardContext({
    super.key,
    required this.state,
    required this.name,
    required this.avatarUrl,
    required this.muted,
    required this.speaking,
    this.volume,
    this.onVolumeChanged,
    this.hasScreen = false,
    this.watchingScreen = false,
    this.isLocal = false,
    this.onScreenTap,
    this.previewIdentity = 'participant',
    this.previewThumbnail,
    this.previewCaption = 'Экран',
    this.microphoneUnavailable = false,
    this.deafened = false,
  });
  final AppState state;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool speaking;
  final int? volume;
  final ValueChanged<int>? onVolumeChanged;
  final bool hasScreen;
  final bool watchingScreen;
  final bool isLocal;
  final VoidCallback? onScreenTap;
  final String previewIdentity;
  final Uint8List? previewThumbnail;
  final String previewCaption;
  final bool microphoneUnavailable;
  final bool deafened;
}
