import 'dart:convert';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const viewerLeaseId = '11111111-1111-4111-8111-111111111111';
const ownerLeaseId = '22222222-2222-4222-8222-222222222222';
const watcherAccountId = '33333333-3333-4333-8333-333333333333';
const screenTrackSid = 'TR_screen_123';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=test-session',
    });
  });

  test('reports and stops an active screen subscription privately', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await api.setScreenViewerPresence(
      viewerLeaseId,
      ownerLeaseId,
      screenTrackSid,
    );
    await api.stopScreenViewerPresence(
      viewerLeaseId,
      ownerLeaseId,
      screenTrackSid,
    );

    expect(requests, hasLength(2));
    expect(requests[0].method, 'PUT');
    expect(
      requests[0].url.path,
      '/api/v1/voice/leases/$viewerLeaseId/screen-viewers/$ownerLeaseId',
    );
    expect(jsonDecode(requests[0].body), {'track_sid': screenTrackSid});
    expect(requests[0].headers['cookie'], 'session=test-session');
    expect(requests[0].headers['origin'], 'https://v.bootybay.ru');
    expect(requests[0].headers['cache-control'], 'no-store');

    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, requests[0].url.path);
    expect(requests[1].url.queryParameters, {'track_sid': screenTrackSid});
    expect(requests[1].headers['cookie'], 'session=test-session');
    expect(requests[1].headers['cache-control'], 'no-store');
  });

  test(
    'reads and normalizes owner and selected-viewer audience snapshots',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'viewer_account_ids': [
                  watcherAccountId.toUpperCase(),
                  watcherAccountId,
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final ownerAudience = await api.readScreenViewerAccounts(ownerLeaseId);
      final viewerAudience = await api.readScreenViewerAccountsForViewer(
        viewerLeaseId,
        ownerLeaseId,
      );

      expect(ownerAudience, [watcherAccountId]);
      expect(viewerAudience, [watcherAccountId]);
      expect(
        requests[0].url.path,
        '/api/v1/voice/leases/$ownerLeaseId/screen-viewers',
      );
      expect(
        requests[1].url.path,
        '/api/v1/voice/leases/$viewerLeaseId/screen-viewers/$ownerLeaseId',
      );
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(
        requests.every(
          (request) => request.headers['cache-control'] == 'no-store',
        ),
        isTrue,
      );
      expect(
        requests.every(
          (request) => request.headers['cookie'] == 'session=test-session',
        ),
        isTrue,
      );
    },
  );

  test(
    'rejects malformed audience snapshots and invalid lease identifiers',
    () async {
      var requests = 0;
      final malformed = ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'viewer_account_ids': ['not-an-account-id'],
              }),
            ),
            200,
          );
        }),
      );
      await expectLater(
        malformed.readScreenViewerAccounts(ownerLeaseId),
        throwsFormatException,
      );

      final noNetwork = ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 204);
        }),
      );
      await expectLater(
        noNetwork.setScreenViewerPresence(
          'invalid',
          ownerLeaseId,
          screenTrackSid,
        ),
        throwsArgumentError,
      );
      expect(requests, 1);
    },
  );
}
