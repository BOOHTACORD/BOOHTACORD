import '../../../models.dart';

class WorkspaceEffects {
  const WorkspaceEffects({
    this.audioPanelOpened,
    required this.selectChannel,
    required this.openDirect,
    required this.invalidateText,
    required this.clearText,
    required this.clearDirect,
    required this.error,
    required this.message,
  });
  final Future<void> Function(GuildChannel, {bool Function()? socketCurrent})
  selectChannel;
  final Future<void> Function(DirectConversation) openDirect;
  final void Function() invalidateText;
  final void Function() clearText;
  final void Function() clearDirect;
  final void Function(String?) error;
  final String Function(Object) message;
  final void Function()? audioPanelOpened;
}
