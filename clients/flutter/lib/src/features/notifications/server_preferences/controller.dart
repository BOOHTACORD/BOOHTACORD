import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'client.dart';

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this.client, this.active);
  final NotificationPreferencesClient client;
  final bool Function() active;
  Map<String, dynamic>? snapshot;
  String? error;
  bool busy = false, closed = false;
  Map<String, dynamic>? get settings =>
      snapshot?['settings'] as Map<String, dynamic>?;
  void changed() {
    if (!closed && active()) notifyListeners();
  }

  Future<void> load() async {
    try {
      final loaded = await client.load();
      if (active() && !closed) {
        snapshot = loaded;
        error = null;
        changed();
      }
    } catch (_) {
      if (active()) {
        error = 'Не удалось получить настройки уведомлений.';
        changed();
      }
    }
  }

  Future<void> update(void Function(Map<String, dynamic>) edit) async {
    final before = settings;
    if (before == null || busy || !active()) return;
    busy = true;
    error = null;
    changed();
    try {
      final value = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(before)) as Map,
      );
      edit(value);
      final saved = await client.save(value, before['revision'] as int);
      if (active() && !closed) snapshot = saved;
    } on NotificationPreferenceError catch (failure) {
      if (active() && !closed) {
        if (failure.status == 409) {
          await load();
          error = 'Настройки изменились на другом устройстве. Показан актуальный выбор сервера.';
        } else {
          error = 'Не удалось сохранить настройки уведомлений.';
        }
      }
    } catch (_) {
      if (active()) error = 'Не удалось сохранить настройки уведомлений.';
    } finally {
      if (active() && !closed) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> importLegacy(bool localDisabled) async {
    final before = settings;
    if (before == null || busy || !active()) return;
    busy = true;
    changed();
    try {
      final saved = await client.importExplicit(
        [],
        localDisabled,
        before['revision'],
      );
      if (active() && !closed) snapshot = saved;
    } on NotificationPreferenceError catch (failure) {
      if (active()) {
        if (failure.status == 409) await load();
        error = 'Перенос не выполнен. Проверьте актуальные настройки сервера.';
      }
    } catch (_) {
      if (active()) error = 'Не удалось перенести настройки. Повторите после проверки соединения.';
    } finally {
      if (active() && !closed) {
        busy = false;
        changed();
      }
    }
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}
