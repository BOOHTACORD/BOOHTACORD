import 'dart:math' as math;

import '../native_bindings.dart';
import '../member_profile_popover/component.dart';
import 'popover_layout.dart';

Future<void> openMemberProfileOverlay({
  required BuildContext context,
  required AppState state,
  required String memberId,
  required Rect Function() anchor,
  required ValueChanged<BuildContext?> onContext,
}) async {
  final revision = state.workspace.selectionRevision;
  final panel = state.workspacePanel;
  final account = state.user?.accountId;
  BuildContext? dialog;
  RawDialogRoute<void>? ownedRoute;
  var closing = false;
  void close() {
    final target = dialog;
    if (!closing && target != null && target.mounted) {
      closing = true;
      final route = ownedRoute;
      if (route?.isCurrent == true) {
        Navigator.of(target).pop();
      } else if (route?.isActive == true) {
        route!.navigator?.removeRoute(route);
      }
    }
  }

  void changed() {
    if (state.workspace.selectionRevision != revision ||
        state.workspacePanel != panel ||
        state.user?.accountId != account)
      close();
  }

  state.addListener(changed);
  try {
    final route = RawDialogRoute<void>(
      barrierDismissible: true,
      barrierLabel: 'Закрыть профиль участника',
      barrierColor: const Color(0x14000000),
      // Keep popover dismissal atomic with focus/semantics restoration.
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) {
        dialog = context;
        onContext(context);
        final media = MediaQuery.of(context), size = MediaQuery.sizeOf(context);
        final dock = state.voiceChannel == null ? 0.0 : 88.0;
        final top = media.padding.top + 8;
        final bounds = Rect.fromLTRB(
          media.padding.left + 8,
          top,
          math.max(
            media.padding.left + 8,
            size.width - media.padding.right - 8,
          ),
          math.max(
            top,
            size.height -
                math.max(media.padding.bottom, media.viewInsets.bottom) -
                dock -
                8,
          ),
        );
        return Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: 'Профиль участника',
          child: CustomSingleChildLayout(
            delegate: MemberPopoverLayout(anchor: anchor(), bounds: bounds),
            child: SingleChildScrollView(
              primary: false,
              child: WorkspaceMemberProfilePopover(
                key: ValueKey(memberId),
                state: state,
                memberId: memberId,
                width: 288,
                onClose: close,
                onOpenDirectMessage: (member) async {
                  close();
                  await state.createDirectConversation(
                    DirectCandidate(
                      id: member.id,
                      displayName: member.displayName,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    ownedRoute = route;
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
  } finally {
    state.removeListener(changed);
    onContext(null);
  }
}
