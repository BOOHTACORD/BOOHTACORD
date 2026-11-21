import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';
import 'package:boohtacord_desktop/src/models.dart';

import '../issue689_support.dart' show waitFor;
import 'api.dart';
import 'storage.dart';
export 'capture.dart';
export 'restart.dart';

class R1Tls extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4910 &&
            sha256.convert(cert.der).toString() ==
                const String.fromEnvironment('QA_CERT_SHA256');
}

class R1Harness {
  R1Harness(this.tester, this.binding, {this.beforeAuthenticate});
  final Future<void> Function()? beforeAuthenticate;
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  late NativeR1Api api, peerApi;
  late AppState app, peer;
  late GuildChannel voice, text;
  late String categoryId;
  final boundary = GlobalKey();
  final report = <String, Object?>{'screenshots': <String, String>{}};
  static const password = String.fromEnvironment('QA_PASSWORD');
  bool get fresh =>
      app.realtime.connected &&
      app.maintenanceKnown &&
      app.voiceRoster.phase == VoiceRosterPhase.fresh;
  int get participants =>
      app.voiceRosters
          ?.where((r) => r.channelId == voice.id)
          .firstOrNull
          ?.participants
          .length ??
      -1;
  bool hasChannel(String name) =>
      app.topology?.categories
          .expand((c) => c.channels)
          .any((c) => c.name == name) ??
      false;
  Future<void> wait(bool Function() condition) => waitFor(tester, condition);
  Future<T?> real<T>(Future<T> Function() action) => tester.runAsync(action);
  Future<T?> realPeer<T>(Future<T> Function() action) =>
      tester.runAsync(() => peerCookies(action));

  Future<void> setup() async {
    expect(
      const String.fromEnvironment('QA_API_BASE'),
      'https://localhost:4910/api/v1',
    );
    expect(password, isNotEmpty);
    HttpOverrides.global = R1Tls();
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://localhost:4910/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues(R1Cookies());
    api = NativeR1Api();
    peerApi = NativeR1Api();
    app = AppState(api);
    peer = AppState(peerApi);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BoohtacordApp(state: app),
      ),
    );
    await real(app.initialize);
    await beforeAuthenticate?.call();
    await real(() => app.authenticate('qa_admin', password, register: false));
    await wait(() => app.phase == AppPhase.ready && app.realtime.connected);
    await realPeer(peer.initialize);
    await realPeer(
      () => peer.authenticate('qa_r1_member', password, register: true),
    );
    await wait(() => peer.phase == AppPhase.ready && peer.realtime.connected);
  }

  Future<void> cleanup() async {
    api.releaseAll();
    peerApi.releaseAll();
    await peerCookies(peer.leaveVoice);
    await app.session.logout();
    await peerCookies(peer.session.logout);
    app.dispose();
    peer.dispose();
    HttpOverrides.global = null;
  }
}
