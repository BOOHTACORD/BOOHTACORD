import 'dart:async';
import 'dart:ui';

import '../../models.dart';
import '../../features/admin/shell/types.dart';
import '../../services/client_telemetry.dart';

import 'package:window_manager/window_manager.dart';

import '../../app_state.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../core/session/scope.dart';
import '../../services/composer_draft_memory.dart';
import '../../services/conversation_scroll_memory.dart';
import '../../features/workspace/search/session.dart';
import '../../features/updates/desktop/artifact.dart';
import '../../features/updates/restore/checkpoint.dart';
import '../../features/updates/restore/window_bounds.dart';

import 'package:screen_retriever/screen_retriever.dart';

class DesktopWorkspacePersistence {
  DesktopWorkspacePersistence(
    this.state,
    this.store, {
    this.installationNamespace = '',
  });
  final String installationNamespace;
  final AppState state;
  final DesktopCheckpointStore store;
  Timer? _timer;
  String? _loadedScope;
  bool _restoring = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  String? _lastSnapshot;
  String get scope => desktopScope(
    state.serverUrl,
    '${state.user?.accountId ?? 'signed-out'}\u0000$installationNamespace',
  );
  void start() {
    state.addListener(_changed);
    ComposerDraftMemory.changed = _schedule;
    ConversationScrollMemory.changed = _schedule;
    _changed();
  }

  void _changed() {
    if (_disposed || state.phase != AppPhase.ready || state.user == null) {
      return;
    }
    if (_shutdown != null &&
        (_shutdown!.scope != scope || !_shutdown!.ticket.isActive)) {
      _shutdown = null;
    }
    if (_loadedScope != scope) {
      if (!_restoring) unawaited(_restore());
      return;
    }
    _schedule();
  }

  void _schedule() {
    if (_disposed ||
        _restoring ||
        _shutdown != null ||
        state.phase != AppPhase.ready ||
        state.user == null ||
        _timer?.isActive == true) {
      return;
    }
    _timer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(flush().catchError((Object _) {})),
    );
  }

  Future<Map<String, dynamic>> capture() async {
    final account = state.user?.accountId;
    final bounds = await windowManager.getBounds();
    return {
      'channel': state.selectedChannel?.id,
      'direct': state.selectedDirectMessage?.id,
      'navigation': state.navigationSection.name,
      'panel': state.workspacePanel.name,
      'profile_section': state.workspace.profileSection.name,
      'admin_section': state.workspace.adminSection.name,
      'drafts': account == null
          ? <Object>[]
          : ComposerDraftMemory.exportForAccount(account),
      'scroll': account == null
          ? <Object>[]
          : ConversationScrollMemory.exportForAccount(account),
      'search': {
        for (final e in state.workspace.searchSessions.entries)
          e.key: {
            'query': e.value.query,
            'scope': e.value.scope,
            'offset': e.value.scrollOffset,
            'should_search': e.value.shouldSearch,
          },
      },
      'window': {
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'muted': state.microphoneMuted,
      'deafened': state.deafened,
      'muted_before_deafen': state.voice.mutedBeforeDeafen,
      'voice_channel': state.voiceChannel?.id,
      'screen_was_active': state.screenSharePhase == ScreenSharePhase.sharing,
    };
  }

  Future<void> flush() async {
    final ticket = scope;
    if (_disposed ||
        _shutdown != null ||
        state.phase != AppPhase.ready ||
        _loadedScope != ticket) {
      return;
    }
    final snapshot = await capture();
    if (_disposed || _shutdown != null || ticket != scope) return;
    final fingerprint = snapshot.toString();
    if (fingerprint == _lastSnapshot) return;
    final previous = _writes;
    _writes = previous
        .catchError((Object _) {})
        .then((_) => store.save(ticket, 'workspace', snapshot));
    await _writes;
    if (!_disposed && ticket == scope) _lastSnapshot = fingerprint;
  }

  Future<void> checkpoint(
    String transaction,
    VerifiedInstallArtifact artifact,
  ) async {
    _timer?.cancel();
    final ticket = scope;
    final snapshot = await capture();
    if (ticket != scope) throw const FormatException('checkpoint_scope');
    // A transient earlier background save must not poison every later restart.
    // The fresh writes below must still succeed before applying any update.
    await _writes.catchError((Object _) {});
    await store.save(ticket, 'workspace', snapshot);
    await store.save(ticket, 'restart', {
      'transaction': transaction,
      'expected_release': artifact.releaseId,
      'expected_build': artifact.nativeBuild,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String(),
      'workspace': snapshot,
    });
  }

  String get _route =>
      '${state.navigationSection.name}/${state.selectedChannel?.id}/${state.selectedDirectMessage?.id}/${state.workspacePanel.name}';

  Future<void> _restore() async {
    _restoring = true;
    final ticket = scope;
    final draftRevision = ComposerDraftMemory.revision;
    final scrollRevision = ConversationScrollMemory.revision;
    final initialRoute = _route;
    final initialPanel = state.workspacePanel;
    final initialProfileSection = state.workspace.profileSection;
    final initialAdminSection = state.workspace.adminSection;
    final initialSearch = Map.of(state.workspace.searchSessions);
    final initialAudio = (
      state.microphoneMuted,
      state.deafened,
      state.voice.mutedBeforeDeafen,
    );
    if (_loadedScope != null && _loadedScope != ticket) {
      ComposerDraftMemory.clear();
      ConversationScrollMemory.clear();
    }
    try {
      final snapshot = await store.read(ticket, 'workspace');
      if (_disposed || ticket != scope || state.phase != AppPhase.ready) return;
      if (snapshot != null) {
        // Reload authorized resources; cached route IDs never grant access.
        await state.refreshTopology();
        if (_disposed || ticket != scope) return;
        await state.refreshDirectMessages();
        if (_disposed || ticket != scope) return;
        final account = state.user!.accountId;
        final direct = state.directMessages
            .where((e) => e.id == snapshot['direct'])
            .firstOrNull;
        final channel = state.topology?.categories
            .expand((e) => e.channels)
            .where(
              (e) => e.id == snapshot['channel'] && e.kind == ChannelKind.text,
            )
            .firstOrNull;
        if (_route != initialRoute) {
          // A user navigation made while local storage/network was loading wins.
        } else if (snapshot['navigation'] == 'directMessages' &&
            direct == null) {
          await state.showDirectMessages();
        } else if (direct != null) {
          await state.showDirectMessages();
          await state.openDirectConversation(direct);
        } else if (channel != null) {
          await state.selectChannel(channel);
        }
        if (_disposed || ticket != scope) return;
        final savedScroll = snapshot['scroll'] as List<dynamic>? ?? [];
        final scrollKey = state.selectedDirectMessage == null
            ? state.selectedChannel?.id
            : 'dm:${state.selectedDirectMessage!.id}';
        final savedPosition = savedScroll
            .whereType<Map>()
            .where((e) => e['channel'] == scrollKey)
            .firstOrNull;
        final anchor = savedPosition?['anchor'];
        final selection = state.workspace.selectionRevision;
        final deadline = DateTime.now().add(const Duration(seconds: 12));
        if (anchor is String && savedPosition?['follow_latest'] != true) {
          for (
            var page = 0;
            page < 40 && DateTime.now().isBefore(deadline);
            page++
          ) {
            if (_disposed ||
                ticket != scope ||
                state.workspace.selectionRevision != selection) {
              break;
            }
            if (state.selectedDirectMessage != null) {
              if (state.directMessageHistory.any((m) => m.id == anchor) ||
                  !await state.loadOlderDirectMessages()) {
                break;
              }
            } else {
              if (state.messages.any((m) => m.id == anchor) ||
                  !await state.loadOlderMessages()) {
                break;
              }
            }
          }
        }
        if (_disposed || ticket != scope) return;
        ConversationScrollMemory.importForAccount(
          account,
          savedScroll,
          unchangedSince: scrollRevision,
        );
        final replies = <String, Object>{
          for (final m in state.messages) m.id: m,
          for (final m in state.directMessageHistory) m.id: m,
        };
        final selectedDraft = (snapshot['drafts'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .where(
              (d) =>
                  d['conversation'] ==
                      (state.selectedDirectMessage?.id ??
                          state.selectedChannel?.id) &&
                  d['kind'] ==
                      (state.selectedDirectMessage != null
                          ? 'directMessage'
                          : 'channel'),
            )
            .firstOrNull;
        final replyId = selectedDraft?['reply_id'];
        if (replyId is String && !replies.containsKey(replyId)) {
          try {
            if (state.selectedDirectMessage != null) {
              final page = await state.api.directMessageHistoryPage(
                state.selectedDirectMessage!.id,
                at: replyId,
              );
              for (final message in page.messages) {
                if (message.id == replyId) replies[message.id] = message;
              }
            } else if (state.selectedChannel != null) {
              final page = await state.api.messagePage(
                state.selectedChannel!.id,
                at: replyId,
              );
              for (final message in page.messages) {
                if (message.id == replyId) replies[message.id] = message;
              }
            }
          } catch (_) {}
        }
        if (_disposed || ticket != scope) return;
        ComposerDraftMemory.importForAccount(
          account,
          snapshot['drafts'] as List<dynamic>? ?? [],
          replies: replies,
          unchangedSince: draftRevision,
        );
        final panel = WorkspacePanel.values
            .where((p) => p.name == snapshot['panel'])
            .firstOrNull;
        if (panel != null &&
            state.workspacePanel == initialPanel &&
            (panel != WorkspacePanel.admin || state.user!.isAdmin) &&
            panel != WorkspacePanel.searchContext) {
          state.workspacePanel = panel;
        }
        final profileSection = ProfileSection.values
            .where((section) => section.name == snapshot['profile_section'])
            .firstOrNull;
        if (profileSection != null &&
            state.workspace.profileSection == initialProfileSection) {
          state.workspace.profileSection = profileSection;
        }
        final adminSection = AdminSection.values
            .where((section) => section.name == snapshot['admin_section'])
            .firstOrNull;
        if (adminSection != null &&
            state.user!.isAdmin &&
            state.workspace.adminSection == initialAdminSection) {
          state.workspace.adminSection = adminSection;
        }
        final search = snapshot['search'];
        if (search is Map) {
          for (final e in search.entries.take(20)) {
            final v = e.value;
            if (e.key is String &&
                identical(
                  state.workspace.searchSessions[e.key],
                  initialSearch[e.key],
                ) &&
                v is Map &&
                v['query'] is String &&
                v['scope'] is String &&
                v['offset'] is num) {
              state.workspace.searchSessions[e.key
                  as String] = WorkspaceSearchSession(
                query: v['query'] as String,
                scope: v['scope'] as String,
                scrollOffset: (v['offset'] as num).toDouble(),
                shouldSearch: v['should_search'] == true,
              );
            }
          }
        }
        if (state.voiceChannel == null &&
            (
                  state.microphoneMuted,
                  state.deafened,
                  state.voice.mutedBeforeDeafen,
                ) ==
                initialAudio) {
          state.microphoneMuted = snapshot['muted'] != false;
          state.deafened = snapshot['deafened'] == true;
          state.voice.mutedBeforeDeafen =
              snapshot['muted_before_deafen'] == true;
          state.audioDevices.microphoneMutedIntent =
              state.microphoneMuted || state.deafened;
        }
        final frame = snapshot['window'];
        if (frame is Map &&
            [
              'x',
              'y',
              'width',
              'height',
            ].every((k) => frame[k] is num && (frame[k] as num).isFinite)) {
          final width = (frame['width'] as num).toDouble(),
              height = (frame['height'] as num).toDouble();
          if (width >= 640 &&
              width <= 6000 &&
              height >= 400 &&
              height <= 4000) {
            final displays = await screenRetriever.getAllDisplays();
            if (_disposed || ticket != scope) return;
            await windowManager.setBounds(
              visibleWindowBounds(
                Rect.fromLTWH(
                  (frame['x'] as num).toDouble(),
                  (frame['y'] as num).toDouble(),
                  width,
                  height,
                ),
                [
                  for (final display in displays)
                    (display.visiblePosition ?? Offset.zero) &
                        (display.visibleSize ?? display.size),
                ],
              ),
            );
          }
        }
        if (!_disposed && ticket == scope) {
          state.notifyListeners();
          ClientTelemetry.desktopUpdate('restore');
        }
      }
      if (ticket == scope) _loadedScope = ticket;
    } catch (_) {
      if (ticket == scope) _loadedScope = ticket;
    } finally {
      _restoring = false;
      // Edits made during restoration must be persisted even when no later
      // user action occurs. A changed account must start its own restoration.
      if (!_disposed) {
        if (ticket == scope) {
          _schedule();
        } else {
          _changed();
        }
      }
    }
  }

  ({
    String scope,
    SessionTicket ticket,
    (bool, bool, bool) audio,
    (bool, bool, bool) stoppedAudio,
  })?
  _shutdown;
  (bool, bool, bool) get _audio =>
      (state.microphoneMuted, state.deafened, state.voice.mutedBeforeDeafen);

  Future<void> gracefulShutdown() async {
    _timer?.cancel();
    final current = scope,
        ticket = state.session.scope.capture(),
        audio = _audio;
    bool active() =>
        !_disposed && !state.disposed && ticket.isActive && current == scope;
    _shutdown = (
      scope: current,
      ticket: ticket,
      audio: audio,
      stoppedAudio: audio,
    );
    try {
      await state.stopScreenShare().timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!active()) return;
    try {
      await state.leaveVoice().timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!active()) return;
    try {
      await state.room?.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!active()) return;
    try {
      await state.realtime.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (active()) {
      _shutdown = (
        scope: current,
        ticket: ticket,
        audio: audio,
        stoppedAudio: _audio,
      );
    }
  }

  Future<void> resumeAfterFailedUpdate() async {
    final stopped = _shutdown;
    _shutdown = null;
    if (stopped == null ||
        _disposed ||
        state.disposed ||
        !stopped.ticket.isActive ||
        stopped.scope != scope ||
        state.phase != AppPhase.ready ||
        state.user == null) {
      return;
    }
    // Restore intent only when no fresh choice was made during failure cleanup.
    // Do not rejoin voice, start capture or enable any media track.
    if (_audio == stopped.stoppedAudio) {
      state.microphoneMuted = stopped.audio.$1;
      state.deafened = stopped.audio.$2;
      state.voice.mutedBeforeDeafen = stopped.audio.$3;
    }
    unawaited(state.realtime.connect());
    state.notifyListeners();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    state.removeListener(_changed);
    ComposerDraftMemory.changed = null;
    ConversationScrollMemory.changed = null;
  }
}
