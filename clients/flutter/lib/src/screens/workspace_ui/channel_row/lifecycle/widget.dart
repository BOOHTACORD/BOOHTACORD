import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceChannelRow extends StatefulWidget {
  const WorkspaceChannelRow({
    super.key,
    required this.state,
    required this.channel,
    required this.selected,
    required this.voiceConnected,
    this.favorite = false,
    this.onFavoriteChanged,
    this.favoriteShortcut = false,
    this.showObjectMenu = true,
    required this.onTap,
  });
  final AppState state;
  final GuildChannel channel;
  final bool selected;
  final bool voiceConnected;
  final bool favorite;
  final ValueChanged<bool>? onFavoriteChanged;
  final bool favoriteShortcut;
  final bool showObjectMenu;
  final VoidCallback onTap;

  @override
  State<WorkspaceChannelRow> createState() => WorkspaceChannelRowState();
}

class WorkspaceChannelRowState extends WorkspaceChannelRowStateContext
    with
        WorkspaceChannelRowStateWorkspaceShowObjectMenuBinding,
        WorkspaceChannelRowStateBuildBinding {}
