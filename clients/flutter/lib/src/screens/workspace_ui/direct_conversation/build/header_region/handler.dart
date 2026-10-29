import '../../../header/component.dart';
import '../../../header/conversation_actions.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension DirectConversationHeader on WorkspaceDirectConversationStateContext {
  Widget renderDirectConversationHeader() => WorkspaceHeader(
    icon: Icons.person_outline,
    title: widget.state.directDisplayName(widget.conversation),
    subtitle: widget.state.isSupportConversation(widget.conversation)
        ? 'Поддержка этого сервера'
        : 'Личный диалог',
    mobileConversationLayout: true,
    onToggleNavigation: widget.onToggleNavigation,
    trailing: ConversationHeaderActions(
      state: widget.state,
      direct: true,
      busy: widget.state.loadingDirectMessages,
      onRefresh: () => widget.state.openDirectConversation(widget.conversation),
    ),
  );
}
