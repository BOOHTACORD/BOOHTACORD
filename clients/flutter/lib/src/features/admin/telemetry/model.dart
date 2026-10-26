const telemetryStateLabels = {
  'disabled': 'Отправка выключена',
  'unavailable': 'ID установки недоступен',
  'never_connected': 'Нет подтверждения приёма',
  'exporting': 'Центр принимает данные',
  'degraded': 'Ошибка доставки',
  'revoked': 'Регистрация отозвана',
  'stale': 'Нет свежего подтверждения',
};

class TelemetrySettings {
  TelemetrySettings._(
    this.installationId,
    this.mode,
    this.state,
    this.registered,
    this.lastAcceptedAt,
    this.queued,
    this.dropped,
  );
  final String installationId, mode, state;
  final bool registered;
  final String? lastAcceptedAt;
  final int queued, dropped;
  factory TelemetrySettings.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['installation_id'] is! String ||
        !['local_only', 'central'].contains(body['mode']) ||
        !telemetryStateLabels.containsKey(body['state']) ||
        body['registered'] is! bool ||
        !(body['last_accepted_at'] == null ||
            body['last_accepted_at'] is String) ||
        body['queued'] is! int ||
        body['queued'] < 0 ||
        body['dropped'] is! int ||
        body['dropped'] < 0) {
      throw const FormatException('Некорректный ответ телеметрии.');
    }
    return TelemetrySettings._(
      body['installation_id'],
      body['mode'],
      body['state'],
      body['registered'],
      body['last_accepted_at'],
      body['queued'],
      body['dropped'],
    );
  }
}

bool validTelemetryEndpoint(String value) {
  final url = Uri.tryParse(value.trim());
  return url != null &&
      url.scheme == 'https' &&
      url.host.isNotEmpty &&
      url.userInfo.isEmpty &&
      url.fragment.isEmpty &&
      url.query.isEmpty;
}
