import 'dart:typed_data';

import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/receive_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=preview-test',
    });
  });

  test(
    'loads a server preview before LiveKit exposes the remote participant',
    () async {
      const viewerLease = '11111111-1111-4111-8111-111111111111';
      const ownerLease = '22222222-2222-4222-8222-222222222222';
      const generation = '33333333-3333-4333-8333-333333333333';
      final jpeg = Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9]);
      var reads = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          reads++;
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/voice/screen-previews/v1/leases/$ownerLease/$generation',
          );
          return http.Response.bytes(
            jpeg,
            200,
            headers: {
              'content-type': 'image/jpeg',
              'x-screen-preview-revision': '1',
            },
          );
        }),
      );
      final owner = _PreviewOwner(api, viewerLease);
      final receiver = ScreenPreviewReceiver(owner);
      addTearDown(() {
        receiver.clear();
        api.transport.raw.close();
        owner.disposed = true;
      });

      // Realtime can beat LiveKit's participant/publication event. The hint
      // still identifies a server-authorized preview and must not be discarded.
      receiver.updated(ownerLease, generation, 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reads, 1);
      expect(owner.screenThumbnails['voice-lease:$ownerLease'], jpeg);
    },
  );

  test('retries a preview hint when its frame is not readable yet', () async {
    const viewerLease = '11111111-1111-4111-8111-111111111111';
    const ownerLease = '22222222-2222-4222-8222-222222222222';
    const generation = '33333333-3333-4333-8333-333333333333';
    final jpeg = Uint8List.fromList([0xff, 0xd8, 2, 0xff, 0xd9]);
    var reads = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        reads++;
        if (reads == 1) return http.Response('', 204);
        return http.Response.bytes(
          jpeg,
          200,
          headers: {
            'content-type': 'image/jpeg',
            'x-screen-preview-revision': '1',
          },
        );
      }),
    );
    final owner = _PreviewOwner(api, viewerLease);
    final receiver = ScreenPreviewReceiver(owner);
    addTearDown(() {
      receiver.clear();
      api.transport.raw.close();
      owner.disposed = true;
    });

    receiver.updated(ownerLease, generation, 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reads, 1);
    expect(owner.screenThumbnails, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(reads, 2);
    expect(owner.screenThumbnails['voice-lease:$ownerLease'], jpeg);
  });
}

class _PreviewOwner implements VoiceController {
  _PreviewOwner(this.api, this.leaseId);

  @override
  final ApiClient api;
  @override
  final String leaseId;
  @override
  bool disposed = false;
  @override
  Room? room;
  @override
  final Map<String, Uint8List> screenThumbnails = {};
  int notifications = 0;

  @override
  void notifyListeners() => notifications++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
