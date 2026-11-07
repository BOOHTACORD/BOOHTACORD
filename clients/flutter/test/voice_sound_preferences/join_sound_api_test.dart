import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/voice/join_sound/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('upload is bounded and account-fenced; metadata is not audio', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <http.Request>[];
    final transport = ApiTransport(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"id":"a","revision":1,"enabled":false}', 200);
      }),
    );
    final api = JoinSoundApi(transport, 'owner');
    expect((await api.upload(Uint8List.fromList([1, 2])))?['enabled'], false);
    expect(requests.single.headers['x-voice-sound-account'], 'owner');
    expect(requests.single.headers['content-type'], 'application/octet-stream');
    expect(requests.single.followRedirects, false);
    await expectLater(api.upload(Uint8List(2097153)), throwsFormatException);
    expect(requests.length, 1);
  });
}
