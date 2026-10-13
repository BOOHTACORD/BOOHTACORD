import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/screen/sender_metadata/api.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _lease = '11111111-1111-4111-8111-111111111111';
const _origin = 'https://fixture.example.test';

class HangingDescriptorClient extends http.BaseClient {
  final received = Completer<http.AbortableRequest>();
  final aborted = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final value = request as http.AbortableRequest;
    received.complete(value);
    await value.abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(value.url);
  }
}

Map<String, Object?> _descriptor() {
  final fixtures = jsonDecode(
    File('../../contracts/screen-share-profile-v1.fixtures.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  return Map<String, Object?>.from(fixtures['validDescriptor'] as Map);
}

ApiClient _api(http.Client client) {
  final value = ApiClient(client: client);
  value.transport.session.baseUrl = '$_origin/api/v1';
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:$_origin:443': 'session=synthetic-fixture',
    }),
  );

  test(
    'writes only through existing owner endpoint and secure cookie transport',
    () async {
      http.Request? request;
      final api = _api(
        MockClient((value) async {
          request = value;
          return http.Response('', 204);
        }),
      );
      addTearDown(api.transport.raw.close);
      final descriptor = _descriptor();
      await api.updateScreenProfileDescriptor(_lease, descriptor);
      expect(request?.method, 'PUT');
      expect(
        request?.url.toString(),
        '$_origin/api/v1/voice/leases/$_lease/screen-profile/v1',
      );
      expect(request?.headers['cookie'], 'session=synthetic-fixture');
      expect(request?.headers['origin'], _origin);
      expect(request?.headers['content-type'], 'application/json');
      expect(request?.followRedirects, isFalse);
      expect(jsonDecode(request!.body), descriptor);
    },
  );

  test(
    'preserves server ownership rejection and never retries a forbidden write',
    () async {
      var calls = 0;
      final api = _api(
        MockClient((_) async {
          calls++;
          return http.Response(
            '{"error":{"code":"FORBIDDEN","message":"Unavailable"}}',
            403,
          );
        }),
      );
      addTearDown(api.transport.raw.close);
      await expectLater(
        api.updateScreenProfileDescriptor(_lease, _descriptor()),
        throwsA(isA<ApiFailure>().having((v) => v.status, 'status', 403)),
      );
      expect(calls, 1);
    },
  );

  test('closed session makes no descriptor HTTP request', () async {
    var calls = 0;
    final api = _api(
      MockClient((_) async {
        calls++;
        return http.Response('', 204);
      }),
    );
    addTearDown(api.transport.raw.close);
    api.transport.session.scope.close();
    await expectLater(
      api.updateScreenProfileDescriptor(_lease, _descriptor()),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
  });

  test(
    'generation cancellation aborts underlying descriptor request',
    () async {
      final client = HangingDescriptorClient();
      final api = _api(client);
      addTearDown(api.transport.raw.close);
      final abort = Completer<void>();
      final operation = api.updateScreenProfileDescriptor(
        _lease,
        _descriptor(),
        abortTrigger: abort.future,
      );
      final failure = expectLater(
        operation,
        throwsA(isA<ScreenProfileWriteAborted>()),
      );
      await client.received.future.timeout(const Duration(seconds: 1));
      abort.complete();
      await failure;
      await client.aborted.future;
    },
  );

  test(
    'HTTP deadline releases caller and cancels underlying operation',
    () async {
      final client = HangingDescriptorClient();
      final api = _api(client);
      addTearDown(api.transport.raw.close);
      final operation = api.updateScreenProfileDescriptor(
        _lease,
        _descriptor(),
        timeout: const Duration(milliseconds: 100),
      );
      final failure = expectLater(operation, throwsA(isA<TimeoutException>()));
      await client.received.future.timeout(const Duration(seconds: 1));
      await failure;
      await client.aborted.future;
    },
  );
}
