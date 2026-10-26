part of 'enroll.dart';

extension MobileActivation on MobileEnrollment {
  Future<Map<String, dynamic>> _activate(
    Map<String, dynamic> cached,
    String scope,
    bool Function() active,
  ) async {
    if (!active()) throw const PushUnavailable('cancelled');
    final response = await api.checked(
      'POST',
      '/notification-devices/${cached['id']}/activate',
      {
        'expected_generation': cached['generation'],
        'receipt': cached['receipt'],
      },
    );
    if (!active() || response['account_id'] != api.account) {
      throw const PushUnavailable('cancelled');
    }
    final value = {
      ...cached,
      ...Map<String, dynamic>.from(response['device'] as Map),
      'phase': 'active',
    }..remove('pending_expected_generation');
    await storage.write(scope, value);
    return value;
  }
}
