import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boohtacord_desktop/src/core/session/session_store.dart';

import '../../integration_test/r1_native/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native peer and observer keep separate cookies across asynchronous callbacks', () async {
    FlutterSecureStorage.setMockInitialValues(R1Cookies());
    final observer = SessionStore(), peer = SessionStore();
    await observer.writeCookie('synthetic-observer');
    await peerCookies(() async {
      await Future<void>.delayed(Duration.zero);
      await peer.writeCookie('synthetic-peer');
    });
    expect(await observer.readCookie(), 'synthetic-observer');
    expect(await peerCookies(peer.readCookie), 'synthetic-peer');
  });
  test(
    'logging out observer cannot clear the independent peer session',
    () async {
      FlutterSecureStorage.setMockInitialValues(R1Cookies());
      final observer = SessionStore(), peer = SessionStore();
      await observer.writeCookie('synthetic-observer');
      await peerCookies(() => peer.writeCookie('synthetic-peer'));
      await observer.clearCookie();
      expect(await observer.readCookie(), isNull);
      expect(await peerCookies(peer.readCookie), 'synthetic-peer');
    },
  );
}
