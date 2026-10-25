import '../remote_payload/utc.dart';

const _modes = {'all', 'mentions', 'none'};

bool validServerPreference(dynamic value) {
  if (value is! Map || !_modes.contains(value['mode'])) return false;
  final pause = value['paused_until'];
  return pause == null ||
      (pause is String &&
          (pause.endsWith('Z') || pause.endsWith('+00:00')) &&
          notificationUtc(pause) != null);
}

Map<String, dynamic> validateNotificationSnapshot(Map<String, dynamic> body) {
  final capability = body['capability'];
  final settings = body['settings'];
  if (capability is! Map ||
      settings is! Map ||
      capability['version'] != 1 ||
      capability['available'] is! bool ||
      capability['device_transport'] is! String ||
      settings['version'] != 1) {
    throw StateError('Unsupported notification settings');
  }
  final revision = settings['revision'];
  final overrides = settings['overrides'];
  if (revision is! int ||
      revision < 0 ||
      revision > 9007199254740991 ||
      settings['enabled'] is! bool ||
      settings['imported'] is! bool ||
      !validServerPreference(settings['dm']) ||
      !validServerPreference(settings['text']) ||
      overrides is! List ||
      overrides.length > 100) {
    throw StateError('Invalid settings');
  }
  for (final value in overrides) {
    if (value is! Map ||
        !{'CHANNEL', 'DIRECT_MESSAGE'}.contains(value['kind']) ||
        value['id'] is! String ||
        !validServerPreference(value)) {
      throw StateError('Invalid override');
    }
  }
  return body;
}
