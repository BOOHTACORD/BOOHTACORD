import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/app_state.dart';

import 'guarded_http.dart';

class TrackedPublicSocket extends Stream<dynamic> implements WebSocket {
  TrackedPublicSocket(this.inner);
  final WebSocket inner;
  bool closed = false;
  @override
  Future<void> close([int? code, String? reason]) async {
    await inner.close(code, reason);
    closed = true;
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => inner.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  int get readyState => inner.readyState;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SocketOnlyApi extends ApiClient {
  SocketOnlyApi._(this._guarded) : super(client: _guarded);
  factory SocketOnlyApi() => SocketOnlyApi._(GuardedHttpClient());
  final GuardedHttpClient _guarded;
  int sockets = 0, pollingRequests = 0;
  int get legacyRequests => _guarded.legacyRequests + pollingRequests;
  final publicSockets = <TrackedPublicSocket>[];

  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) {
    sockets++;
    return super.openRealtime(after: after, client: client);
  }

  @override
  Future<WebSocket> openPublicRealtime() async {
    final socket = TrackedPublicSocket(await super.openPublicRealtime());
    publicSockets.add(socket);
    return socket;
  }

  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() {
    pollingRequests++;
    throw StateError('legacy roster polling requested');
  }
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120 && !ready(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
}

Future<void> captureUnknownMaintenance(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  AppState app,
) async {
  await tester.runAsync(app.maintenance.suspend);
  await tester.pumpAndSettle();
  expect(find.textContaining('Проверяем статус обслуживания'), findsOneWidget);
  if (Platform.isAndroid) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
  }
  if (!Platform.isWindows) {
    await binding.takeScreenshot('android-maintenance-unknown');
  }
  final version = find.textContaining('Версия ');
  await tester.ensureVisible(version);
  await tester.pumpAndSettle();
  if (!Platform.isWindows) {
    await binding.takeScreenshot('android-maintenance-unknown-scrolled');
  }
  final bottom =
      (tester.view.physicalSize.height - tester.view.viewPadding.bottom) /
      tester.view.devicePixelRatio;
  expect(tester.getRect(version).bottom, lessThanOrEqualTo(bottom));
  await tester.runAsync(app.maintenance.useGuest);
  await waitFor(tester, () => app.maintenanceKnown);
  await tester.ensureVisible(find.byKey(const ValueKey('auth-login-field')));
  await tester.pumpAndSettle();
}
