part of 'enroll.dart';

extension MobilePreparation on MobileEnrollment {
  Future<Map<String, dynamic>> prepare(
    Map<String, dynamic> cached,
    String scope,
    bool Function() active,
    PushRegistration registration,
  ) async {
    if (preparationExpired(cached)) {
      cached = Map.of(cached)
        ..remove('pending_expected_generation')
        ..remove('receipt');
    }
    final instance = cached['instance_id'] as String? ?? const Uuid().v4();
    final expected =
        cached['pending_expected_generation'] as int? ??
        cached['generation'] as int? ??
        0;
    cached = {
      ...cached,
      'instance_id': instance,
      'pending_expected_generation': expected,
      'phase': 'registering',
      'prepared_at': cached.containsKey('pending_expected_generation')
          ? cached['prepared_at']
          : DateTime.now().toUtc().toIso8601String(),
    };
    await storage.write(scope, cached);
    if (!active()) throw const PushUnavailable('cancelled');
    final id = cached['id'] as String?;
    final prepared = await api.checked(
      expected == 0 ? 'POST' : 'PUT',
      '/notification-devices${expected == 0 ? '' : '/$id'}',
      {
        'instance_id': instance,
        'expected_generation': expected,
        'transport': 'mobile_relay',
        'namespace': config.namespace,
        'consent_version': 1,
        'permission': registration.permission == PushPermission.provisional
            ? 'provisional'
            : 'granted',
      },
    );
    if (!active() || prepared['account_id'] != api.account) {
      throw const PushUnavailable('cancelled');
    }
    final device = Map<String, dynamic>.from(prepared['device'] as Map);
    cached = {...cached, ...device};
    if (!active()) throw const PushUnavailable('cancelled');
    await storage.write(scope, cached);
    return prepared;
  }
}

bool preparationExpired(Map<String, dynamic> value) {
  final began = DateTime.tryParse(value['prepared_at'] as String? ?? '');
  return began != null &&
      DateTime.now().toUtc().difference(began) >= const Duration(minutes: 5);
}
