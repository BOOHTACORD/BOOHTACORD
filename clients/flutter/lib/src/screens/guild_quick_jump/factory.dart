import '../../app_state.dart';
import '../../features/workspace/quick_jump/state/controller.dart';
import '../../features/workspace/quick_jump/state/effects.dart';

QuickJumpController guildQuickJumpOwner(AppState state) => QuickJumpController(
  state.api,
  state.session.scope,
  readAccount: () => state.user?.accountId,
  readTopology: () => state.topology,
  readDirects: () => state.directMessages,
  effects: QuickJumpEffects(
    acceptTopology: (value) => state.topology = value,
    acceptDirects: (value) => state.directMessages = value,
    openChannel: (value) async {
      state.closeSearchPanel(restoreLauncherFocus: false);
      await state.selectChannel(value);
    },
    openDirect: (value) async {
      state.closeSearchPanel(restoreLauncherFocus: false);
      await state.openDirectConversation(value);
    },
  ),
);
