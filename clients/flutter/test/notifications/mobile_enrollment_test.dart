import 'package:flutter_test/flutter_test.dart';
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
  test(
    'cancelled A registration cannot persist or activate a route for B',
    () async {
      final store = MemoryBindingStorage(), driver = FakePushDriver();
      var requests = 0, active = true;
      final transport = ApiTransport(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      final flow = MobileEnrollment(
        api: NotificationApi(transport, 'A'),
        driver: driver,
        config: testConfig,
        storage: store,
        inbox: ChallengeInbox(),
      );
      final pending = flow.enable(
        testCapability,
        'scope-A',
        () => active,
        askPermission: true,
      );
      final failure = expectLater(
        pending,
        throwsA(
          isA<PushUnavailable>().having((e) => e.reason, 'reason', 'cancelled'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      active = false;
      driver.registration.complete(
        const PushRegistration(
          PushPermission.granted,
          'fcm_fid',
          'synthetic-fid',
        ),
      );
      await failure;
      expect(store.values, isEmpty);
      expect(requests, 0);
      flow.close();
      transport.client.close();
    },
  );
  test(
    'changed relay pin requires explicit enrollment rather than cached success',
    () async {
      final store = MemoryBindingStorage(), driver = FakePushDriver();
      store.values['scope'] = {
        'phase': 'active',
        'relay_public_key': 'previous-publisher-key',
        'installation_key': 'synthetic-pin',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .toIso8601String(),
      };
      final transport = ApiTransport(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      final flow = MobileEnrollment(
        api: NotificationApi(transport, 'A'),
        driver: driver,
        config: testConfig,
        storage: store,
        inbox: ChallengeInbox(),
      );
      await expectLater(
        flow.enable(testCapability, 'scope', () => true, askPermission: false),
        throwsA(
          isA<PushUnavailable>().having(
            (e) => e.reason,
            'reason',
            'installation_changed',
          ),
        ),
      );
      expect(driver.prompts, 0);
      flow.close();
      transport.client.close();
    },
  );
  test('challenge inbox rejects malformed IDs and bounds buffered proofs', () async {
    final inbox = ChallengeInbox();
    expect(
      inbox.accept({
        'relay_challenge':
            '{"challenge_id":"------------------------------------","nonce":"${'a' * 43}"}',
      }),
      false,
    );
  });
}
