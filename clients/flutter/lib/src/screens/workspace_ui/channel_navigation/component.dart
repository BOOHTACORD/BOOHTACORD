import '../../../features/workspace/navigation/favorites/preferences.dart';
import '../category/component.dart';
import '../channel_row/component.dart';
import '../native_bindings.dart';

/// Channel list with account-scoped shortcuts for the user's favorite channels.
class WorkspaceChannelNavigation extends StatefulWidget {
  const WorkspaceChannelNavigation({
    super.key,
    required this.state,
    this.onChannelSelected,
  });

  final AppState state;
  final VoidCallback? onChannelSelected;

  @override
  State<WorkspaceChannelNavigation> createState() =>
      _WorkspaceChannelNavigationState();
}

class _WorkspaceChannelNavigationState
    extends State<WorkspaceChannelNavigation> {
  Set<String> _favoriteIds = <String>{};
  Set<String> _knownChannelIds = <String>{};
  String? _scope;
  int _generation = 0;

  String? get _accountId => widget.state.profile?.accountId;
  String get _baseUrl => widget.state.serverUrl;

  @override
  void initState() {
    super.initState();
    _knownChannelIds = _allChannelIds(widget.state.topology);
    _loadFavorites();
  }

  @override
  void didUpdateWidget(covariant WorkspaceChannelNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextScope = _accountId == null ? null : '$_accountId\u0000$_baseUrl';
    if (_scope != nextScope) {
      _favoriteIds = <String>{};
      _loadFavorites();
    }
    final currentIds = _allChannelIds(widget.state.topology);
    if (!setEquals(_knownChannelIds, currentIds)) {
      _knownChannelIds = currentIds;
      _pruneFavorites(currentIds);
    }
  }

  Future<void> _loadFavorites() async {
    final accountId = _accountId;
    final generation = ++_generation;
    if (accountId == null || accountId.isEmpty) {
      _scope = null;
      if (mounted) setState(() => _favoriteIds = <String>{});
      return;
    }

    final scope = '$accountId\u0000$_baseUrl';
    _scope = scope;
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        _scope == scope &&
        _accountId == accountId &&
        _baseUrl == widget.state.serverUrl;
    final preferences = ChannelFavoritesPreferences(
      accountId: accountId,
      baseUrl: _baseUrl,
      current: isCurrent,
    );
    final saved = await preferences.read();
    if (!isCurrent()) return;
    final available = _allChannelIds(widget.state.topology);
    final pruned = saved.intersection(available);
    setState(() => _favoriteIds = pruned);
    if (pruned.length != saved.length) await preferences.save(pruned);
  }

  Future<void> _toggleFavorite(GuildChannel channel, bool favorite) async {
    final accountId = _accountId;
    final scope = _scope;
    if (accountId == null ||
        scope == null ||
        scope != '$accountId\u0000$_baseUrl') {
      return;
    }
    setState(() {
      if (favorite) {
        _favoriteIds.add(channel.id);
      } else {
        _favoriteIds.remove(channel.id);
      }
    });
    final generation = _generation;
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        _scope == scope &&
        _accountId == accountId;
    await ChannelFavoritesPreferences(
      accountId: accountId,
      baseUrl: _baseUrl,
      current: isCurrent,
    ).save(_favoriteIds);
  }

  void _pruneFavorites(Set<String> currentIds) {
    final pruned = _favoriteIds.intersection(currentIds);
    if (pruned.length == _favoriteIds.length) return;
    setState(() => _favoriteIds = pruned);
    final accountId = _accountId;
    if (accountId == null) return;
    final generation = _generation;
    final scope = _scope;
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        _scope == scope &&
        _accountId == accountId;
    ChannelFavoritesPreferences(
      accountId: accountId,
      baseUrl: _baseUrl,
      current: isCurrent,
    ).save(pruned);
  }

  void _selectChannel(GuildChannel channel) {
    if (widget.onChannelSelected != null && channel.kind == ChannelKind.voice) {
      widget.state.enterVoiceChannel(channel);
    } else {
      widget.state.selectChannel(channel);
    }
    widget.onChannelSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final topology = widget.state.topology;
    if (topology == null) return const SizedBox.shrink();
    final orderedChannels = topology.categories
        .expand((category) => category.channels)
        .where((channel) => _favoriteIds.contains(channel.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'КАНАЛЫ',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
            TopologyCreateButton(state: widget.state),
          ],
        ),
        if (orderedChannels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 5),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: GcColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'ИЗБРАННОЕ',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
          for (final channel in orderedChannels)
            WorkspaceChannelRow(
              key: ValueKey('workspace-favorite-shortcut:${channel.id}'),
              state: widget.state,
              channel: channel,
              selected: widget.state.selectedChannel?.id == channel.id,
              voiceConnected: widget.state.voiceChannel?.id == channel.id,
              voiceParticipantCount: _voiceParticipantCount(channel),
              favorite: true,
              favoriteShortcut: true,
              showObjectMenu: false,
              onTap: () => _selectChannel(channel),
            ),
          const SizedBox(height: 8),
        ],
        for (final category in topology.categories)
          WorkspaceCategory(
            key: ValueKey('workspace-category:${category.id}'),
            state: widget.state,
            category: category,
            favoriteIds: _favoriteIds,
            onFavoriteChanged: (channel, favorite) =>
                _toggleFavorite(channel, favorite),
            onChannelSelected: widget.onChannelSelected,
          ),
        if (topology.categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Каналы пока не созданы.',
              style: TextStyle(color: GcColors.muted),
            ),
          ),
      ],
    );
  }

  int? _voiceParticipantCount(GuildChannel channel) {
    if (widget.state.voiceChannel?.id == channel.id) {
      final room = widget.state.room;
      if (room?.localParticipant != null) {
        return room!.remoteParticipants.length + 1;
      }
    }
    return widget.state.voiceRosters
        ?.where((item) => item.channelId == channel.id)
        .firstOrNull
        ?.participants
        .length;
  }

  Set<String> _allChannelIds(ChannelTopology? topology) =>
      topology?.categories
          .expand((category) => category.channels)
          .map((channel) => channel.id)
          .toSet() ??
      <String>{};
}
