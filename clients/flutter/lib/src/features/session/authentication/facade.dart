import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AuthSessionFacade on ApiFacadeBase {
  late final _authSession = AuthSessionApi(transport);

  Future<SessionUser?> currentSession() =>
      transport.run(() => _authSession.currentSession(), allowClosed: true);

  Future<SessionUser?> currentRealtimeSession(
    Future<void> abortTrigger,
    bool Function() isCurrent,
  ) => transport.run(
    () => _authSession.currentSession(
      abortTrigger: abortTrigger,
      isCurrent: isCurrent,
    ),
    allowClosed: true,
  );

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) => transport.run(
    () => _authSession.authenticate(login, password, register: register),
    allowClosed: true,
  );

  Future<void> logout() =>
      transport.run(() => _authSession.logout(), allowClosed: true);
}
