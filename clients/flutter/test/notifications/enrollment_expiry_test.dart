import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_driver/contracts.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_enrollment/challenge_inbox.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_enrollment/enroll.dart';
import 'package:boohtacord_desktop/src/features/notifications/server_preferences/api.dart';

import 'mobile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('expired preparation rotates its own known generation instead of an endless stale POST retry', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = MemoryBindingStorage();
    final cached = <String, dynamic>{
      'id': 'binding',
      'instance_id': 'instance',
      'generation': 1,
      'pending_expected_generation': 0,
      'prepared_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 6))
          .toIso8601String(),
      'phase': 'registering',
    };
    final transport = ApiTransport(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        final body = jsonDecode(request.body);
        expect(body['expected_generation'], 1);
        return http.Response(
          jsonEncode({
            'account_id': 'A',
            'device': {
              'id': 'binding',
              'instance_id': 'instance',
              'generation': 2,
            },
            'nonce': 'synthetic',
          }),
          200,
        );
      }),
    );
    final flow = MobileEnrollment(
      api: NotificationApi(transport, 'A'),
      driver: FakePushDriver(),
      config: testConfig,
      storage: store,
      inbox: ChallengeInbox(),
    );
    final result = await flow.prepare(
      cached,
      'scope',
      () => true,
      const PushRegistration(
        PushPermission.granted,
        'fcm_fid',
        'synthetic-fid',
      ),
    );
    expect(result['device']['generation'], 2);
    expect(store.values['scope']?['pending_expected_generation'], 1);
    flow.close();
    transport.client.close();
  });
}
