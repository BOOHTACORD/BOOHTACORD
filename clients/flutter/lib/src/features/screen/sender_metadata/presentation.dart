import 'model.dart';

String senderModeLabel(String? mode) => switch (mode) {
  'motion' => 'Плавность',
  'text' => 'Чёткость текста',
  _ => 'Нет данных от отправителя',
};

String senderRequestedProfileLabel(String? id) {
  if (id == null) return 'Нет данных от отправителя';
  final match = RegExp(r'^P(720|1080|1440)_(15|30|60)$').firstMatch(id);
  if (match == null) return 'Нет данных от отправителя';
  return '${match[1]}p · ${match[2]} FPS';
}

Map<String, String> senderConfigurationLabels(
  ScreenShareSenderDescriptor? descriptor,
) {
  final profile = descriptor?.effectiveProfile;
  final capture = profile?['capture'] as Map?;
  final encoding = profile?['encoding'] as Map?;
  final layers = encoding?['layers'] as List?;
  final state = descriptor?.publisherState;
  final status = descriptor == null
      ? 'Нет подтверждения от отправителя'
      : state == 'sharing'
      ? 'Конфигурация передана отправителем'
      : {'updating', 'publishing', 'capturing'}.contains(state)
      ? 'Обновление конфигурации ожидается'
      : 'Предыдущая конфигурация · трансляция завершена';
  return {
    'Подтверждение конфигурации': status,
    'Источник конфигурации': descriptor == null
        ? 'Источник конфигурации неизвестен'
        : 'SDK отправителя · лимиты, не измеренный FPS',
    'Лимиты захвата SDK': capture == null
        ? 'Нет данных'
        : '${capture['max_width']} × ${capture['max_height']} · до ${capture['max_fps']} FPS',
    'Лимиты кодирования SDK': layers == null
        ? 'Нет данных'
        : layers
              .asMap()
              .entries
              .map((entry) {
                final layer = entry.value as Map;
                final mbps = (layer['max_bitrate_bps'] as num) / 1000000;
                return '${entry.key + 1}: ${layer['width']} × ${layer['height']} · до ${layer['max_fps']} FPS · ${mbps.toStringAsFixed(1)} Мбит/с';
              })
              .join(' · '),
    'Возраст захвата': 'Возраст захвата неизвестен',
  };
}

String senderMetadataReceiptAge(DateTime? receivedAt, DateTime now) {
  if (receivedAt == null) return 'Время получения неизвестно';
  final seconds = now
      .difference(receivedAt)
      .inSeconds
      .clamp(0, 9007199254740991);
  return 'Получено этим клиентом $seconds с назад';
}

Map<String, String> localSenderConfigurationLabels(
  ScreenShareSenderDescriptor? descriptor, {
  String? selectedProfileId,
  String? selectedMode,
  String? writeStatus,
  DateTime? confirmedAt,
}) {
  final confirmed = senderConfigurationLabels(descriptor);
  final previous = descriptor != null && confirmedAt == null;
  return {
    'Выбрано пользователем': senderRequestedProfileLabel(selectedProfileId),
    'Выбранный режим': senderModeLabel(selectedMode),
    'Подтверждение конфигурации': switch (writeStatus) {
      'applied' => 'Записано сервером',
      'unavailable' => 'Недоступно',
      _ => 'Ожидается подтверждение',
    },
    'Источник конфигурации': confirmed['Источник конфигурации']!,
    previous ? 'Предыдущие лимиты захвата SDK' : 'Лимиты захвата SDK':
        confirmed['Лимиты захвата SDK']!,
    previous ? 'Предыдущие лимиты кодирования SDK' : 'Лимиты кодирования SDK':
        confirmed['Лимиты кодирования SDK']!,
    'Возраст захвата': 'Возраст захвата неизвестен',
  };
}
