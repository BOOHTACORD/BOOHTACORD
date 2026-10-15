import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/admin/shell/types.dart';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app/desktop_updates/workspace.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/checkpoint.dart';
import 'package:boohtacord_desktop/src/features/workspace/search/session.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/conversation_scroll_memory.dart';

import 'package_fixture.dart';

class RestoreStore extends DesktopCheckpointStore {
  RestoreStore() : super(Directory.systemTemp);
  final requested = Completer<void>();
  final loaded = Completer<Map<String, dynamic>?>();
  final saved = Completer<Map<String, dynamic>>();
  final firstAttempt = Completer<void>();
  bool failFirst = false;
  int attempts = 0;
  final savedKinds = <String>[];
  @override
  Future<void> save(
    String scope,
    String kind,
    Map<String, dynamic> value,
  ) async {
    attempts++;
    savedKinds.add(kind);
    if (!firstAttempt.isCompleted) firstAttempt.complete();
    if (failFirst && attempts == 1) throw const FileSystemException('fixture');
    if (!saved.isCompleted) saved.complete(value);
  }

  @override
  Future<Map<String, dynamic>?> read(String scope, String kind) {
    requested.complete();
    return loaded.future;
  }
}

class RestoreState extends AppState {
  RestoreState() : super(ApiClient());
  int refreshes = 0;
  @override
  Future<void> refreshTopology() async {
    refreshes++;
  }

  @override
  Future<void> refreshDirectMessages() async {}
  @override
  Future<void> showDirectMessages() async {
    workspace.navigationSection = NavigationSection.directMessages;
    selectedChannel = null;
  }

  @override
  Future<void> selectChannel(GuildChannel channel) async {
    selectedChannel = channel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          if (call.method == 'getBounds') {
            return {'x': 0.0, 'y': 0.0, 'width': 1200.0, 'height': 800.0};
          }
          throw StateError('Unexpected window request');
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });
  for (final admin in [false, true]) {
    test('restores settings sections with current admin ACL: $admin', () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = SessionUser(
          accountId: 'fixture',
          role: admin ? 'ADMINISTRATOR' : 'MEMBER',
        );
      final store = RestoreStore();
      final persistence = DesktopWorkspacePersistence(state, store);
      addTearDown(() {
        persistence.dispose();
        state.dispose();
      });
      persistence.start();
      await store.requested.future;
      store.loaded.complete({
        'panel': 'admin',
        'profile_section': 'about',
        'admin_section': 'roles',
      });
      final captured = await store.saved.future.timeout(
        const Duration(seconds: 2),
      );
      expect(state.workspace.profileSection, ProfileSection.about);
      expect(
        state.workspace.adminSection,
        admin ? AdminSection.roles : AdminSection.members,
      );
      expect(
        state.workspacePanel,
        admin ? WorkspacePanel.admin : WorkspacePanel.none,
      );
      expect(captured['profile_section'], 'about');
      expect(captured['admin_section'], admin ? 'roles' : 'members');
    });
  }

  test(
    'fresh settings sections and navigation win over delayed disk state',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'ADMINISTRATOR');
      final store = RestoreStore();
      final persistence = DesktopWorkspacePersistence(state, store);
      addTearDown(() {
        persistence.dispose();
        state.dispose();
      });
      persistence.start();
      await store.requested.future;
      state.workspace.profileSection = ProfileSection.notifications;
      state.workspace.adminSection = AdminSection.audit;
      state.workspace.navigationSection = NavigationSection.directMessages;
      store.loaded.complete({
        'navigation': 'channels',
        'profile_section': 'about',
        'admin_section': 'roles',
      });
      await store.saved.future.timeout(const Duration(seconds: 2));
      expect(state.workspace.profileSection, ProfileSection.notifications);
      expect(state.workspace.adminSection, AdminSection.audit);
      expect(state.navigationSection, NavigationSection.directMessages);
    },
  );

  test('restores the DM list even without a selected conversation', () async {
    final state = RestoreState()
      ..phase = AppPhase.ready
      ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
    final store = RestoreStore();
    final persistence = DesktopWorkspacePersistence(state, store);
    addTearDown(() {
      persistence.dispose();
      state.dispose();
    });
    persistence.start();
    await store.requested.future;
    store.loaded.complete({'navigation': 'directMessages'});
    await store.saved.future.timeout(const Duration(seconds: 2));
    expect(state.navigationSection, NavigationSection.directMessages);
    expect(state.selectedDirectMessage, isNull);
  });

  test(
    'fresh panel, search, scroll and audio choices win over a delayed restore',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
      final store = RestoreStore();
      final persistence = DesktopWorkspacePersistence(state, store);
      final restored = Completer<void>();
      state.addListener(() {
        if (store.loaded.isCompleted && !restored.isCompleted) {
          restored.complete();
        }
      });
      addTearDown(() {
        persistence.dispose();
        state.dispose();
        ConversationScrollMemory.clear();
      });
      state.microphoneMuted = true;
      state.deafened = false;
      state.workspace.searchSessions['removed'] = const WorkspaceSearchSession(
        query: 'remove me',
        scope: 'all',
        scrollOffset: 1,
        shouldSearch: true,
      );
      persistence.start();
      await store.requested.future;
      state.workspacePanel = WorkspacePanel.audio;
      const fresh = WorkspaceSearchSession(
        query: 'fresh',
        scope: 'all',
        scrollOffset: 22,
        shouldSearch: true,
      );
      state.workspace.searchSessions['fixture'] = fresh;
      state.workspace.searchSessions.remove('removed');
      state.microphoneMuted = false;
      state.deafened = true;
      ConversationScrollMemory.save(
        accountId: 'fixture',
        channelId: 'channel',
        offset: 99,
        followLatest: true,
        epoch: ConversationScrollMemory.epoch,
      );
      store.loaded.complete({
        'panel': 'profile',
        'muted': true,
        'deafened': false,
        'scroll': [
          {'channel': 'channel', 'offset': 10, 'follow_latest': false},
        ],
        'search': {
          'fixture': {'query': 'old', 'scope': 'all', 'offset': 1},
          'removed': {'query': 'old', 'scope': 'all', 'offset': 1},
          'untouched': {'query': 'retained', 'scope': 'all', 'offset': 5},
        },
      });
      await restored.future.timeout(const Duration(seconds: 2));
      expect(state.workspacePanel, WorkspacePanel.audio);
      expect(state.workspace.searchSessions['fixture'], same(fresh));
      expect(state.workspace.searchSessions.containsKey('removed'), false);
      expect(state.workspace.searchSessions['untouched']?.query, 'retained');
      expect(state.microphoneMuted, false);
      expect(state.deafened, true);
      expect(ConversationScrollMemory.load('fixture', 'channel')?.offset, 99);
      final persisted = await store.saved.future.timeout(
        const Duration(seconds: 2),
      );
      expect(persisted['panel'], 'audio');
      expect(persisted['deafened'], true);
    },
  );
  test(
    'an untouched workspace still restores its saved panel and audio',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
      final store = RestoreStore();
      final persistence = DesktopWorkspacePersistence(state, store);
      final restored = Completer<void>();
      state.addListener(() {
        if (store.loaded.isCompleted && !restored.isCompleted) {
          restored.complete();
        }
      });
      addTearDown(() {
        persistence.dispose();
        state.dispose();
        ConversationScrollMemory.clear();
      });
      state.microphoneMuted = true;
      state.deafened = false;
      persistence.start();
      await store.requested.future;
      store.loaded.complete({
        'panel': 'profile',
        'muted': false,
        'deafened': true,
      });
      await restored.future.timeout(const Duration(seconds: 2));
      expect(state.workspacePanel, WorkspacePanel.profile);
      expect(state.microphoneMuted, false);
      expect(state.deafened, true);
    },
  );
  test(
    'disposing during a delayed read prevents subsequent state mutation',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
      final store = RestoreStore();
      final persistence = DesktopWorkspacePersistence(state, store);
      addTearDown(state.dispose);
      persistence.start();
      await store.requested.future;
      persistence.dispose();
      store.loaded.complete({'panel': 'profile'});
      await Future<void>.delayed(Duration.zero);
      expect(state.refreshes, 0);
      expect(state.workspacePanel, WorkspacePanel.none);
    },
  );
  test(
    'a failed workspace save can retry the unchanged current snapshot',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
      final store = RestoreStore()..failFirst = true;
      final persistence = DesktopWorkspacePersistence(state, store);
      addTearDown(() {
        persistence.dispose();
        state.dispose();
      });
      persistence.start();
      await store.requested.future;
      store.loaded.complete({});
      await store.firstAttempt.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      await persistence.flush();
      expect(store.attempts, 2);
      expect(store.saved.isCompleted, true);
    },
  );
  test(
    'a checkpoint retries storage after a previous background write failed',
    () async {
      final state = RestoreState()
        ..phase = AppPhase.ready
        ..user = const SessionUser(accountId: 'fixture', role: 'MEMBER');
      final store = RestoreStore()..failFirst = true;
      final persistence = DesktopWorkspacePersistence(state, store);
      addTearDown(() {
        persistence.dispose();
        state.dispose();
      });
      persistence.start();
      await store.requested.future;
      store.loaded.complete({});
      await store.firstAttempt.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      await persistence.checkpoint(
        'fixture-transaction',
        await testPackage([1]),
      );
      expect(store.savedKinds, ['workspace', 'workspace', 'restart']);
    },
  );
}
