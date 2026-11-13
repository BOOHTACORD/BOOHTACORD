import 'dart:async';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class DelayedClient extends http.BaseClient {
  final seen = Completer<void>();
  final response = Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    seen.complete();
    return response.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late 401 after cancellation cannot clear the session cookie', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = DelayedClient();
    final api = ApiClient(client: client);
    await api.transport.session.writeCookie('local-test-cookie');
    final abort = Completer<void>();
    var active = true;
    final result = api.currentRealtimeSession(abort.future, () => active);
    await client.seen.future;
    active = false;
    abort.complete();
    client.response.complete(http.StreamedResponse(const Stream.empty(), 401));
    await expectLater(result, throwsA(isA<http.RequestAbortedException>()));
    expect(await api.transport.session.readCookie(), 'local-test-cookie');
    client.close();
  });
}
