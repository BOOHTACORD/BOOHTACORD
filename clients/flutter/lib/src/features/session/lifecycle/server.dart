import 'controller.dart';

extension SessionServerChange on SessionController {
  Future<void> setServer(String value) async {
    if (closing) await waitForClose();
    final ticket = scope.close();
    effects.invalidateOperations?.call();
    await closeWith(() async {
      try {
        await effects.beforeServerChange();
        await effects.closeMedia();
        await effects.closeRealtime();
        await api.setBaseUrl(value);
        if (!ticket.isCurrent) return;
        user = null;
        await effects.clearServer();
        if (!ticket.isCurrent) return;
        phase = AppPhase.signedOut;
        effects.error(null);
        changed();
      } catch (_) {
        scope.resume(ticket);
        try {
          await effects.resume?.call();
        } catch (_) {}
        rethrow;
      }
    });
  }
}
