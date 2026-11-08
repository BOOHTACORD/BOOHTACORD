part of '../audio_device_check.dart';

InputDevice? resolveInputDevice({
  required String? selectedId,
  required String? selectedLabel,
  required List<InputDevice> available,
  String? recorderDeviceId,
}) {
  final mappedId = recorderDeviceId?.trim();
  if (mappedId != null && mappedId.isNotEmpty) {
    for (final device in available) {
      if (device.id == mappedId) return device;
    }
  }
  final id = selectedId?.trim();
  if (id == null || id.isEmpty || id == 'default') return null;
  for (final device in available) {
    if (device.id == id) return device;
  }
  final label = _normalizeDeviceLabel(selectedLabel);
  if (label.isNotEmpty) {
    for (final device in available) {
      if (_normalizeDeviceLabel(device.label) == label) return device;
    }
  }
  throw const AudioDeviceCheckFailure(
    'Не удалось найти выбранный микрофон для локальной проверки. Обновите список устройств.',
  );
}

PlaybackDevice? resolvePlaybackDevice({
  required String? selectedId,
  required String? selectedLabel,
  required List<PlaybackDevice> available,
}) {
  final id = selectedId?.trim();
  if (id == null || id.isEmpty || id == 'default') {
    for (final device in available) {
      if (device.isDefault) return device;
    }
    return null;
  }
  // Android communication outputs use AudioManager routes and are not
  // represented by SoLoud's integer device IDs. The app selects the route
  // before this local check, so SoLoud must use the current system route.
  if (AndroidAudioDevices.isNativeOutputRoute(id)) return null;
  final parsedId = int.tryParse(id);
  if (parsedId != null) {
    for (final device in available) {
      if (device.id == parsedId) return device;
    }
  }
  final fullLabel = selectedLabel?.trim().toLowerCase() ?? '';
  if (fullLabel.isNotEmpty) {
    for (final device in available) {
      if (device.name.trim().toLowerCase() == fullLabel) return device;
    }
    final label = _normalizeDeviceLabel(fullLabel);
    final matches = available.where(
      (device) => _normalizeDeviceLabel(device.name) == label,
    );
    if (matches.length == 1) return matches.single;
  }
  throw const AudioDeviceCheckFailure(
    'Не удалось найти выбранный динамик для локальной проверки. Обновите список устройств.',
  );
}

double amplitudePercentFromDb(double db) {
  if (!db.isFinite || db <= -100) return 0;
  return math.pow(10, db / 20).clamp(0, 1).toDouble();
}

String _normalizeDeviceLabel(String? label) =>
    label?.trim().toLowerCase().replaceFirst(RegExp(r'\s*\([^)]*\)$'), '') ??
    '';
