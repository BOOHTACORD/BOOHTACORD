import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app/desktop_updates/workspace.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/checkpoint.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import '../../realtime_scope/fakes.dart';

class ResumeApi extends ApiClient {
  int connections = 0;
  @override
  Future<WebSocket> openRealtime() async {
    connections++;
    return SocketFake();
  }
}

class ResumeState extends AppState {
  ResumeState(super.api);
  int screenStops = 0, voiceLeaves = 0;
  Future<void> Function()? onScreenStop;
  @override
  Future<void> stopScreenShare() async {
    screenStops++;
    await onScreenStop?.call();
  }

  @override
  Future<void> leaveVoice() async {
    voiceLeaves++;
    microphoneMuted = false;
    deafened = false;
    voice.mutedBeforeDeafen = false;
  }
}

class ResumeStore extends DesktopCheckpointStore {
  ResumeStore() : super(Directory.systemTemp);
  Map<String, dynamic>? workspace;
  @override
  Future<Map<String, dynamic>?> read(String scope, String kind) async => null;
  @override
  Future<void> save(
    String scope,
    String kind,
    Map<String, dynamic> value,
  ) async {
    if (kind == 'workspace') workspace = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ResumeApi api;
  late ResumeState state;
  late DesktopWorkspacePersistence workspace;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          (call) async => {
            'x': 0.0,
            'y': 0.0,
            'width': 1200.0,
            'height': 800.0,
          },
        );
    api = ResumeApi();
    state = ResumeState(api)
      ..phase = AppPhase.ready
      ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER')
      ..microphoneMuted = true
      ..deafened = true;
    workspace = DesktopWorkspacePersistence(
      state,
      DesktopCheckpointStore(Directory.systemTemp),
    );
  });
  tearDown(() {
    workspace.dispose();
    state.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });
  test('failed apply reconnects chat and restores audio intent without rejoining media', () async {
    final old = SocketFake();
    state.realtime.socket = old;
    await workspace.gracefulShutdown();
    expect(old.closed, true);
    expect(state.realtime.socket, isNull);
    await workspace.resumeAfterFailedUpdate();
    await Future<void>.delayed(Duration.zero);
    expect(api.connections, 1);
    expect(state.realtime.socket, isNotNull);
    expect(state.microphoneMuted, true);
    expect(state.deafened, true);
    expect(state.room, isNull);
    expect(state.screenStops, 1);
    expect(state.voiceLeaves, 1);
    await workspace.resumeAfterFailedUpdate();
    expect(api.connections, 1);
  });
  test(
    'a new session generation for the same account cannot resume old shutdown',
    () async {
      await workspace.gracefulShutdown();
      state.session.scope.begin();
      await workspace.resumeAfterFailedUpdate();
      expect(api.connections, 0);
      expect(state.microphoneMuted, false);
    },
  );
  test(
    'account replacement cannot receive old audio choices or connection',
    () async {
      await workspace.gracefulShutdown();
      state.user = const SessionUser(accountId: 'other', role: 'MEMBER');
      await workspace.resumeAfterFailedUpdate();
      expect(api.connections, 0);
      expect(state.deafened, false);
    },
  );
  test(
    'fresh audio choice while failure is being handled wins over checkpoint',
    () async {
      await workspace.gracefulShutdown();
      state.microphoneMuted = true;
      await workspace.resumeAfterFailedUpdate();
      expect(state.microphoneMuted, true);
      expect(state.deafened, false);
      await Future<void>.delayed(Duration.zero);
      expect(api.connections, 1);
    },
  );
  test(
    'scope change during screen shutdown cannot close the new connection',
    () async {
      final waiting = Completer<void>();
      state.onScreenStop = () => waiting.future;
      final stopped = workspace.gracefulShutdown();
      state.session.scope.begin();
      final fresh = SocketFake();
      state.realtime.socket = fresh;
      waiting.complete();
      await stopped;
      await workspace.resumeAfterFailedUpdate();
      expect(state.voiceLeaves, 0);
      expect(fresh.closed, false);
      expect(state.realtime.socket, same(fresh));
      expect(api.connections, 0);
    },
  );
  test(
    'shutdown cannot overwrite the saved pre-restart audio preferences',
    () async {
      workspace.dispose();
      final store = ResumeStore();
      workspace = DesktopWorkspacePersistence(state, store)..start();
      await Future<void>.delayed(Duration.zero);
      await workspace.flush();
      expect(store.workspace?['muted'], true);
      expect(store.workspace?['deafened'], true);
      await workspace.gracefulShutdown();
      await workspace.flush();
      expect(store.workspace?['muted'], true);
      expect(store.workspace?['deafened'], true);
      await workspace.resumeAfterFailedUpdate();
      await workspace.flush();
      expect(store.workspace?['muted'], true);
    },
  );
  test('disposed workspace does not reconnect or mutate audio', () async {
    await workspace.gracefulShutdown();
    workspace.dispose();
    await workspace.resumeAfterFailedUpdate();
    expect(api.connections, 0);
    expect(state.deafened, false);
  });
}
