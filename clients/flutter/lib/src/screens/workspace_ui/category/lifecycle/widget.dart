import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceCategory extends StatefulWidget {
  const WorkspaceCategory({
    super.key,
    required this.state,
    required this.category,
    this.favoriteIds = const <String>{},
    this.onFavoriteChanged,
    this.onChannelSelected,
  });
  final AppState state;
  final ChannelCategory category;
  final Set<String> favoriteIds;
  final void Function(GuildChannel channel, bool favorite)? onFavoriteChanged;
  final VoidCallback? onChannelSelected;

  @override
  State<WorkspaceCategory> createState() => WorkspaceCategoryState();
}

class WorkspaceCategoryState extends WorkspaceCategoryStateContext
    with
        WorkspaceCategoryStateWorkspaceShowObjectMenuBinding,
        WorkspaceCategoryStateBuildBinding {}
