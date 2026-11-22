import 'package:flutter/foundation.dart' show mapEquals;

import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../feedback/handler.dart';

extension RoleSaveAction on RolePermissionsContext {
  Future<void> executeSavePermissions() async {
    if (!mounted ||
        saving ||
        loading ||
        denied ||
        !dirty ||
        role != GuildRole.member ||
        selected?.editable != true) {
      return;
    }
    final api = widget.api;
    final expectedRevision = revision;
    final generation = loadGeneration;
    final before = Map<GuildPermission, bool>.of(baseline);
    final proposed = Map<GuildPermission, bool>.of(draft);
    final newDeletes = deleteKeys.any(
      (key) => baseline[key] != true && draft[key] == true,
    );
    if (newDeletes && !await confirmDeletes()) return;
    if (!mounted ||
        saving ||
        loading ||
        denied ||
        widget.api != api ||
        role != GuildRole.member ||
        selected?.editable != true ||
        revision != expectedRevision ||
        generation != loadGeneration ||
        !mapEquals(proposed, draft)) {
      return;
    }
    mutate(() {
      saving = true;
      error = null;
      status = null;
      conflict = false;
    });
    try {
      await api.saveMemberRolePolicy(
        revision: expectedRevision,
        values: proposed,
        confirmDeleteGrants: newDeletes,
      );
      if (!mounted) return;
      final refreshed = await loadRoles(reset: true);
      if (!mounted) return;
      await widget.onSaved();
      if (mounted) {
        mutate(
          () => status = refreshed
              ? 'Разрешения сохранены.'
              : 'Разрешения сохранены, но не удалось обновить значения.',
        );
      }
    } catch (cause) {
      if (!mounted) return;
      if (cause is ApiFailure && cause.status == 409) {
        mutate(() {
          conflict = true;
          conflictBefore = before;
          conflictCurrent = null;
          error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
        });
        await loadRoles(reset: false);
      } else if (mounted) {
        mutate(() {
          denied =
              cause is ApiFailure &&
              (cause.status == 401 || cause.status == 403);
          error = rolePermissionsFailureMessage(cause);
        });
      }
    } finally {
      if (mounted) mutate(() => saving = false);
    }
  }
}
