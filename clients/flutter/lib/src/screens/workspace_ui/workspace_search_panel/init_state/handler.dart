import '../../native_bindings.dart';
import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateInitStateBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceWorkspaceSearchPanelStateInitState();
  }
}

extension WorkspaceWorkspaceSearchPanelStateInitStateAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateInitState() {
    final current = workspaceCurrentConversation();
    pinsMode = state.workspace.searchPinsRequested && current?.direct == false;
    final sessionKey = current == null
        ? 'all'
        : '${current.direct ? 'dm' : 'channel'}:${current.id}';
    workspaceSearchSessionKey = sessionKey;
    workspaceSearchSessionEpoch = state.workspace.searchSessionEpoch;
    final session = state.workspace.searchSessions[sessionKey];
    workspaceScope = session?.scope ?? (current == null ? 'all' : 'current');
    workspaceQuery = TextEditingController(text: session?.query ?? '');
    workspaceScroll = ScrollController();
    workspaceRestoreScrollOffset = session?.scrollOffset ?? 0;
    workspaceLastScrollOffset = workspaceRestoreScrollOffset;
    workspaceScroll.addListener(() {
      if (workspaceScroll.hasClients) {
        workspaceLastScrollOffset = workspaceScroll.offset;
        workspaceSaveSearchSession();
      }
    });
    final restoreResults =
        session?.shouldSearch == true && workspaceQuery.text.trim().isNotEmpty;
    if (restoreResults) workspaceLoading = true;
    workspaceQuery.addListener(workspaceQueryChanged);
    if (restoreResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) workspaceSearch();
      });
    }
  }
}
