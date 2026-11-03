import 'package:flutter/material.dart';

import '../devices/state.dart';

enum AudioDeviceNoticeTone { pending, warning }

class AudioDeviceScanNoticeCopy {
  const AudioDeviceScanNoticeCopy(
    this.title,
    this.detail,
    this.icon,
    this.tone,
  );

  final String title;
  final String? detail;
  final IconData icon;
  final AudioDeviceNoticeTone tone;

  static AudioDeviceScanNoticeCopy? fromState({
    required AudioDeviceScanStatus status,
    required AudioDeviceScanFailure? failure,
    required int inputCount,
    required int outputCount,
  }) {
    if (status == AudioDeviceScanStatus.initializing) {
      return const AudioDeviceScanNoticeCopy(
        'Подключаем аудиоустройства…',
        null,
        Icons.hourglass_top,
        AudioDeviceNoticeTone.pending,
      );
    }
    if (status == AudioDeviceScanStatus.error) return _failure(failure);
    if (status != AudioDeviceScanStatus.ready) return null;
    if (inputCount == 0 && outputCount == 0) {
      return const AudioDeviceScanNoticeCopy(
        'Аудиоустройства не найдены.',
        'Подключите микрофон или динамик и обновите список.',
        Icons.info_outline,
        AudioDeviceNoticeTone.pending,
      );
    }
    return null;
  }

  static AudioDeviceScanNoticeCopy _failure(AudioDeviceScanFailure? failure) =>
      switch (failure) {
        AudioDeviceScanFailure.permissionDenied =>
          const AudioDeviceScanNoticeCopy(
            'macOS запретил доступ к микрофону.',
            'Разрешите BOOHTACORD в Системных настройках → Конфиденциальность и безопасность → Микрофон, затем обновите список.',
            Icons.mic_off_outlined,
            AudioDeviceNoticeTone.warning,
          ),
        AudioDeviceScanFailure.permissionRestricted =>
          const AudioDeviceScanNoticeCopy(
            'Доступ к микрофону ограничен системой.',
            'Проверьте ограничения конфиденциальности macOS. Повторное обновление не запрашивает разрешение автоматически.',
            Icons.lock_outline,
            AudioDeviceNoticeTone.warning,
          ),
        AudioDeviceScanFailure.initializationFailed =>
          const AudioDeviceScanNoticeCopy(
            'Не удалось запустить аудиосистему.',
            'Проверьте подключение устройств и повторите обновление.',
            Icons.error_outline,
            AudioDeviceNoticeTone.warning,
          ),
        AudioDeviceScanFailure.enumerationFailed ||
        null => const AudioDeviceScanNoticeCopy(
          'Не удалось получить список аудиоустройств.',
          'Повторите обновление списка.',
          Icons.error_outline,
          AudioDeviceNoticeTone.warning,
        ),
      };
}
