import 'dart:io';

import '../../../services/api_client.dart';
import 'controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../telemetry/observe_render/workspace.dart';
import '../../../services/client_telemetry.dart';

extension SessionRestoration on SessionController {
  Future<void> initialize() async {
    if (closing) await waitForClose();
    final previousUser = user;
    final flowName = hasInitialized ? 'session.restore' : 'startup';
    hasInitialized = true;
    final ticket = scope.begin();
    if (!ticket.isActive) return;
    phase = AppPhase.loading;
    effects.error(null);
    changed();
    ActionScope? readiness;
    var deadlineExpired = false;
    try {
      final account =
          await (() async {
            await api.initialize();
            if (!ticket.isActive) return null;
            await effects.initialize();
            if (!ticket.isActive) return null;
            final account = await api.currentSession();
            if (!ticket.isActive) return null;
            if (account == null) {
              await effects.clearAccount();
            } else {
              // Account-scoped preparations (audio preferences, notifications,
              // and other local state) read the current account through this
              // controller. Publish the restored account before preparing it,
              // matching the interactive authentication flow.
              user = account;
              readiness = ActionScope(
                flowName,
                api.transport.session.telemetry,
                enabled: ClientTelemetry.enabled,
              )..step('restore');
              await readiness!.run(() => effects.prepare(account));
            }
            return account;
          })().timeout(
            startupTimeout,
            onTimeout: () {
              deadlineExpired = true;
              throw ApiFailure(
                'Подключение не завершилось вовремя. '
                '${Platform.isMacOS ? 'Проверьте системный запрос доступа к Связке ключей и соединение. ' : 'Проверьте соединение. '}'
                'Повторите попытку.',
              );
            },
          );
      if (!ticket.isActive) return;
      user = account;
      if (account == null) {
        phase = AppPhase.signedOut;
      } else {
        phase = AppPhase.ready;
        readiness?.step('workspace');
        await readiness!.run(effects.ready);
        observeWorkspaceReady(
          readiness!,
          () => ticket.isActive && phase == AppPhase.ready,
        );
      }
    } catch (cause) {
      readiness?.finish('failed', reason: 'dependency');
      if (!ticket.isActive) return;
      if (deadlineExpired) {
        // Future.timeout cannot cancel storage/native work. Retire its tickets
        // before showing retry so late completions cannot prepare the account.
        scope.close();
        effects.invalidateOperations?.call();
      }
      user = previousUser;
      phase = AppPhase.connectionError;
      effects.error(effects.message(cause));
      changed();
      return;
    }
    if (ticket.isActive) changed();
  }
}
