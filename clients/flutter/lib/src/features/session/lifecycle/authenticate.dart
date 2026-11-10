import 'controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../telemetry/observe_render/workspace.dart';
import '../../../services/client_telemetry.dart';

extension SessionAuthentication on SessionController {
  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    if (closing) await waitForClose();
    final ticket = scope.begin();
    if (!ticket.isActive) return;
    effects.error(null);
    changed();
    ActionScope? readiness;
    var enteringWorkspace = false;
    try {
      await api.authenticate(login, password, register: register);
      if (!ticket.isActive) return;
      final account = await api.currentSession();
      if (!ticket.isActive) return;
      user = account;
      if (account != null) {
        readiness = ActionScope(
          'auth.login',
          api.transport.session.telemetry,
          enabled: ClientTelemetry.enabled,
        )..step('authenticate');
        await readiness.run(() => effects.prepare(account));
      }
      if (!ticket.isActive) return;
      phase = AppPhase.ready;
      enteringWorkspace = true;
      if (readiness != null) {
        readiness.step('workspace');
        await readiness.run(effects.ready);
        observeWorkspaceReady(
          readiness,
          () => ticket.isActive && phase == AppPhase.ready,
        );
      } else {
        await effects.ready();
      }
    } catch (cause) {
      readiness?.finish('failed', reason: 'dependency');
      if (!ticket.isActive) return;
      if (enteringWorkspace) phase = AppPhase.connectionError;
      effects.error(effects.message(cause));
      rethrow;
    } finally {
      if (ticket.isActive) changed();
    }
  }
}
