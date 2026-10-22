import 'package:flutter/foundation.dart';

import '../../../core/http/api_failure.dart';
import 'model.dart';

class TelemetrySettingsController extends ChangeNotifier {
  TelemetrySettingsController(
    this.read,
    this.write, {
    bool Function()? isCurrent,
  }) : isCurrent = isCurrent ?? (() => true);
  final Future<TelemetrySettings> Function() read;
  final Future<TelemetrySettings> Function(String, String, bool) write;
  final bool Function() isCurrent;
  TelemetrySettings? value;
  String? error;
  bool busy = false, _disposed = false;
  bool get active => !_disposed && isCurrent();
  Future<void> load() => _run(read);
  Future<void> update(
    String mode, {
    String endpoint = '',
    bool confirmed = false,
  }) async {
    if (!active || busy || value == null) return;
    if (!['local_only', 'central'].contains(mode) ||
        mode == 'central' &&
            (!confirmed ||
                !validTelemetryEndpoint(endpoint) ||
                value!.state == 'unavailable')) {
      error = 'Подтвердите согласие и укажите HTTPS-адрес центра.';
      notifyListeners();
      return;
    }
    await _run(() => write(mode, endpoint.trim(), confirmed));
  }

  Future<void> _run(Future<TelemetrySettings> Function() action) async {
    if (!active || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final next = await action();
      if (active) value = next;
    } catch (cause) {
      if (!active) return;
      // A failed refresh is not a current successful delivery state.
      value = null;
      error = cause is ApiFailure && cause.status == 403
          ? 'Нужны права администратора.'
          : cause is ApiFailure && cause.status == 404
          ? 'Сервер пока не поддерживает диагностику установки.'
          : 'Не удалось загрузить диагностику. Проверьте подключение и повторите.';
    } finally {
      busy = false;
      if (active) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    value = null;
    super.dispose();
  }
}
