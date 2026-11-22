import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../feedback/handler.dart';

extension RoleLoadAction on RolePermissionsContext {
  Future<bool> executeLoadRoles({required bool reset}) async {
    if (!mounted) return false;
    final generation = ++loadGeneration;
    mutate(() {
      loading = true;
      error = null;
      status = null;
    });
    try {
      final page = await widget.api.loadRolePolicies();
      final member = page.roles.firstWhere(
        (item) => item.role == GuildRole.member,
      );
      if (!mounted || generation != loadGeneration) return false;
      mutate(() {
        denied = false;
        roles = page.roles;
        revision = page.revision;
        baseline = Map.of(member.permissions);
        if (reset) draft = Map.of(member.permissions);
        if (reset) {
          conflict = false;
          conflictBefore = null;
          conflictCurrent = null;
        } else if (conflict) {
          conflictCurrent = Map.of(member.permissions);
          error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
        }
      });
      return true;
    } catch (cause) {
      if (mounted && generation == loadGeneration) {
        mutate(() {
          denied =
              cause is ApiFailure &&
              (cause.status == 401 || cause.status == 403);
          error = rolePermissionsFailureMessage(cause);
          if (conflict) conflictCurrent = null;
        });
      }
      return false;
    } finally {
      if (mounted && generation == loadGeneration) {
        mutate(() => loading = false);
      }
    }
  }
}
