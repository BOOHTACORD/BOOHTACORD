import '../native_bindings.dart';

/// One touch/keyboard entry point into the existing conversation actions.
class ConversationHeaderActions extends StatefulWidget {
  const ConversationHeaderActions({
    super.key,
    required this.state,
    required this.direct,
    required this.onRefresh,
    this.busy = false,
  });
  final AppState state;
  final bool direct, busy;
  final VoidCallback onRefresh;

  @override
  State<ConversationHeaderActions> createState() =>
      _ConversationHeaderActionsState();
}

class _ConversationHeaderActionsState extends State<ConversationHeaderActions> {
  final _menu = GlobalKey<PopupMenuButtonState<String>>();
  final _focus = FocusNode(debugLabel: 'conversation-actions');
  bool _searchOpen = false;
  Object? _origin;
  AppState get state => widget.state;
  bool get direct => widget.direct;
  bool get busy => widget.busy;
  VoidCallback get onRefresh => widget.onRefresh;
  Object get _context => (
    state.user?.accountId,
    state.selectedChannel?.id,
    state.selectedDirectMessage?.id,
  );
  @override
  void initState() {
    super.initState();
    state.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant ConversationHeaderActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != state) {
      oldWidget.state.removeListener(_changed);
      state.addListener(_changed);
      _searchOpen = false;
    }
  }

  void _changed() {
    if (!_searchOpen ||
        state.workspacePanel == WorkspacePanel.search ||
        state.workspacePanel == WorkspacePanel.searchContext)
      return;
    _searchOpen = false;
    if (state.workspacePanel == WorkspacePanel.none && _origin == _context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focus.canRequestFocus) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    state.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachments = direct
        ? state.directMessageHistory
              .where(
                (m) =>
                    !m.deleted &&
                    m.sendStatus == null &&
                    m.attachments.isNotEmpty,
              )
              .map(
                (m) => (
                  path:
                      '/direct-messages/${Uri.encodeComponent(m.directMessageId)}',
                  files: m.attachments,
                ),
              )
              .toList()
        : state.messages
              .where(
                (m) =>
                    !m.deleted &&
                    m.sendStatus == null &&
                    m.attachments.isNotEmpty,
              )
              .map(
                (m) => (
                  path: '/channels/${Uri.encodeComponent(m.channelId)}',
                  files: m.attachments,
                ),
              )
              .toList();
    return Focus(
      focusNode: _focus,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (_focus.hasPrimaryFocus &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _menu.currentState?.showButtonMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopupMenuButton<String>(
        key: _menu,
        tooltip: 'Действия диалога',
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
        icon: const Icon(Icons.more_horiz),
        onSelected: (action) {
          if (action == 'search' || action == 'pins') {
            _origin = _context;
            _searchOpen = true;
            state.openSearchPanel(
              currentConversation: true,
              pins: action == 'pins',
            );
          } else if (action == 'refresh' && !busy) {
            onRefresh();
          } else if (action == 'files') {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Файлы из загруженной истории'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in attachments)
                          MessageAttachmentList(
                            state: state,
                            parentPath: row.path,
                            attachments: row.files,
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            );
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'search', child: Text('Поиск в диалоге')),
          PopupMenuItem(
            value: 'files',
            enabled: attachments.isNotEmpty,
            child: const Text('Файлы из истории'),
          ),
          if (!direct)
            const PopupMenuItem(value: 'pins', child: Text('Закреплённые')),
          PopupMenuItem(
            value: 'refresh',
            enabled: !busy,
            child: const Text('Обновить историю'),
          ),
        ],
      ),
    );
  }
}
