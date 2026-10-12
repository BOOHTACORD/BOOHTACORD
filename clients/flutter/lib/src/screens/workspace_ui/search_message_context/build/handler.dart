import 'context_messages/handler.dart';
import '../../header/component.dart';
import '../../search_context_message/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceSearchMessageContextStateBuildBinding
    on WorkspaceSearchMessageContextStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceSearchMessageContextStateBuild(context);
  }
}

extension WorkspaceSearchMessageContextStateBuildAction
    on WorkspaceSearchMessageContextStateContext {
  Widget executeWorkspaceSearchMessageContextStateBuild(BuildContext context) {
    final target = widget.state.searchContextMessage;
    final isDirect = target?.kind == SearchMessageKind.directMessage;
    final backLabel = widget.state.searchContextHeading == 'Контекст ответа'
        ? 'К последним сообщениям'
        : 'Вернуться к беседе';
    final List<WorkspaceSearchContextMessage> messages = isDirect
        ? widget.state.searchContextDirectMessages
              .map(
                (message) => WorkspaceSearchContextMessage(
                  id: message.id,
                  authorId: message.authorId,
                  body: message.body,
                  createdAt: message.createdAt,
                  editedAt: message.editedAt,
                  deleted: message.deleted,
                  attachments: message.attachments,
                ),
              )
              .toList(growable: false)
        : widget.state.searchContextTextMessages
              .map(
                (message) => WorkspaceSearchContextMessage(
                  messageKind: message.kind,
                  id: message.id,
                  authorId: message.authorId,
                  body: message.body,
                  createdAt: message.createdAt,
                  editedAt: message.editedAt,
                  deleted: message.deleted,
                  attachments: message.attachments,
                ),
              )
              .toList(growable: false);
    if (target != null && target.id != workspaceLastTargetId) {
      workspaceLastTargetId = target.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = workspaceTargetKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: .35,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 720;
        return Column(
          children: [
            WorkspaceHeader(
              icon: Icons.manage_search,
              title: widget.state.searchContextHeading,
              subtitle: target == null
                  ? ''
                  : isDirect
                  ? widget.state.selectedDirectMessage?.displayName ??
                        'Личный диалог'
                  : '# ${widget.state.selectedChannel?.name ?? 'Текстовый канал'}',
              trailing: compact
                  ? IconButton(
                      tooltip: backLabel,
                      onPressed: widget.state.returnFromSearchContext,
                      icon: const Icon(Icons.arrow_back, size: 18),
                    )
                  : TextButton.icon(
                      onPressed: widget.state.returnFromSearchContext,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(backLabel),
                    ),
            ),
            if (widget.state.searchContextError case final error?)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error,
                        style: const TextStyle(color: GcColors.danger),
                      ),
                      const SizedBox(height: 8),
                      if (target != null)
                        TextButton(
                          onPressed: () => widget.state.openSearchContext(
                            target,
                            heading: widget.state.searchContextHeading,
                          ),
                          child: const Text('Повторить'),
                        ),
                    ],
                  ),
                ),
              )
            else if (widget.state.loadingSearchContext)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              renderSearchMessageContextContextMessages(
                messages,
                target,
                isDirect,
              ),
          ],
        );
      },
    );
  }
}
