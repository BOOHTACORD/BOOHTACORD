import 'package:flutter/foundation.dart';

import '../../../core/http/api_failure.dart';
import '../../guild/profile/model.dart';
import 'model.dart';

class GuildSettingsController extends ChangeNotifier {
  GuildSettingsController(this.read, this.write);
  final Future<GuildSettings> Function() read;
  final Future<GuildSettings> Function(String, String?, int) write;
  String _name = '';
  String? _welcome, error;
  GuildSettings? _baseline;
  bool conflict = false;
  String get name => _name;
  set name(String value) {
    if (_disposed || busy || value == _name) return;
    _name = value;
    saved = false;
    if (!conflict) error = null;
    _notify();
  }

  String? get welcome => _welcome;
  set welcome(String? value) {
    if (_disposed || busy || value == _welcome) return;
    _welcome = value;
    saved = false;
    if (!conflict) error = null;
    _notify();
  }

  bool get dirty =>
      _baseline != null &&
      (_name.trim() != _baseline!.name || _welcome != _baseline!.welcome);

  void _accept(GuildSettings row, {bool keepDraft = false}) {
    _baseline = row;
    revision = row.revision;
    if (!keepDraft) {
      _name = row.name;
      _welcome = row.welcome;
    }
  }

  void cancel() {
    if (_disposed || busy || _baseline == null) return;
    _accept(_baseline!);
    conflict = saved = false;
    error = null;
    _notify();
  }

  int revision = 0;
  bool busy = false, loading = false, saved = false, _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || busy) return;
    busy = loading = true;
    error = null;
    _notify();
    try {
      final row = await read();
      if (_disposed) return;
      _accept(row);
      conflict = saved = false;
    } catch (_) {
      if (!_disposed) error = 'Не удалось загрузить настройки.';
    } finally {
      busy = loading = false;
      _notify();
    }
  }

  Future<void> save(List<String> available) async {
    if (_disposed || busy || revision == 0 || !dirty) return;
    error = null;
    saved = false;
    if (!validGuildName(name.trim())) {
      error = 'Название: от 1 до 80 символов, без переводов строк.';
      _notify();
      return;
    }
    if (welcome != null && !available.contains(welcome)) {
      error = 'Выберите доступный текстовый канал или выключите приветствия.';
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      final row = await write(name.trim(), welcome, revision);
      if (_disposed) return;
      _accept(row);
      conflict = false;
      saved = true;
    } catch (cause) {
      if (_disposed) return;
      error = 'Не удалось сохранить настройки.';
      if (cause is ApiFailure && cause.status == 409) {
        conflict = true;
        error = 'Настройки изменил другой администратор. Проверьте черновик и сохраните снова.';
        try {
          final row = await read();
          if (!_disposed) _accept(row, keepDraft: true);
        } catch (_) {
          if (!_disposed) {
            revision = 0;
            error = 'Перечитайте настройки перед повторной попыткой.';
          }
        }
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
