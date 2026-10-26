import 'package:boohtacord_desktop/src/screens/workspace_ui/connection_status/component.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/sidebar/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/native_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets('sidebar reacts to the live connection controllers', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    state.user = const SessionUser(accountId: 'account-1', role: 'MEMBER');
    state.profile = const OwnProfile(
      accountId: 'account-1',
      login: 'qa',
      displayName: 'QA',
      role: 'MEMBER',
    );
    state.voiceRoster.phase = VoiceRosterPhase.unavailable;

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                state,
                state.realtime,
                state.voiceRoster,
              ]),
              builder: (context, _) => SizedBox(
                width: 300,
                height: 640,
                child: WorkspaceSidebar(state: state),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Чат обновляется'), findsOneWidget);
    expect(find.text('Загружаем состав'), findsNothing);
    expect(find.text('Состав недоступен'), findsOneWidget);

    state.realtime.connected = true;
    state.realtime.changed();
    state.voiceRoster.voiceRosters = [];
    state.voiceRoster.phase = VoiceRosterPhase.fresh;
    state.voiceRoster.lastUpdatedAt = DateTime.now();
    state.voiceRoster.changed();
    await tester.pump();

    expect(find.byKey(const ValueKey('connection-status-card')), findsNothing);

    state.voicePhase = VoicePhase.error;
    state.notifyListeners();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('connection-status-card')),
      findsOneWidget,
    );
    expect(find.text('Голос не подключён'), findsOneWidget);
  });

  testWidgets('shows independent connection states and retry actions', (
    tester,
  ) async {
    var chatRetries = 0;
    var rosterRetries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceConnectionStatus(
              chatConnected: false,
              chatConnecting: false,
              voicePhase: VoicePhase.idle,
              rosterPhase: VoiceRosterPhase.unavailable,
              rosterRetained: false,
              lastUpdatedAt: null,
              rosterCanRetry: true,
              onRetryChat: () => chatRetries++,
              onRetryRoster: () => rosterRetries++,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('connection-status-card')),
      findsOneWidget,
    );
    expect(find.text('Чат обновляется'), findsOneWidget);
    expect(find.text('Голос не подключён'), findsOneWidget);
    expect(find.text('Состав недоступен'), findsOneWidget);
    expect(find.text('Повторить связь чата'), findsOneWidget);
    expect(find.text('Обновить состав'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('connection-status-card')))
          .width,
      lessThanOrEqualTo(280),
    );
    await tester.tap(find.text('Повторить связь чата'));
    await tester.tap(find.text('Обновить состав'));
    expect(chatRetries, 1);
    expect(rosterRetries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows retained roster age and disables retries while busy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceConnectionStatus(
              chatConnected: false,
              chatConnecting: true,
              voicePhase: VoicePhase.reconnecting,
              rosterPhase: VoiceRosterPhase.stale,
              rosterRetained: true,
              lastUpdatedAt: DateTime.now().subtract(
                const Duration(seconds: 69),
              ),
              rosterCanRetry: false,
              onRetryChat: () {},
              onRetryRoster: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^Состав устарел · \d+ с\. назад$')
                .hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Повторить связь чата'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('hides the card when all three services are healthy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceConnectionStatus(
              chatConnected: true,
              chatConnecting: false,
              voicePhase: VoicePhase.connected,
              rosterPhase: VoiceRosterPhase.fresh,
              rosterRetained: true,
              lastUpdatedAt: DateTime.now(),
              rosterCanRetry: false,
              onRetryChat: () {},
              onRetryRoster: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('connection-status-card')), findsNothing);
  });

  testWidgets('connection status card desktop visual capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();

    const boundaryKey = ValueKey('connection-status-desktop-capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          backgroundColor: GcColors.sidebar,
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: const SizedBox(
                width: 320,
                height: 380,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: WorkspaceConnectionStatus(
                    chatConnected: false,
                    chatConnecting: false,
                    voicePhase: VoicePhase.idle,
                    rosterPhase: VoiceRosterPhase.unavailable,
                    rosterRetained: false,
                    lastUpdatedAt: null,
                    rosterCanRetry: true,
                    onRetryChat: _noop,
                    onRetryRoster: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await captureUiuxBoundary(
      tester,
      find.byKey(boundaryKey),
      fileName: 'flutter-connection-status-desktop-320x380.png',
      pixelRatio: 1,
    );
  });

  testWidgets('connection status card mobile visual capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();

    const boundaryKey = ValueKey('connection-status-mobile-capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          backgroundColor: GcColors.sidebar,
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: const SizedBox(
                width: 320,
                height: 380,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: WorkspaceConnectionStatus(
                    chatConnected: false,
                    chatConnecting: true,
                    voicePhase: VoicePhase.reconnecting,
                    rosterPhase: VoiceRosterPhase.stale,
                    rosterRetained: true,
                    lastUpdatedAt: null,
                    rosterCanRetry: false,
                    onRetryChat: _noop,
                    onRetryRoster: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await captureUiuxBoundary(
      tester,
      find.byKey(boundaryKey),
      fileName: 'flutter-connection-status-mobile-320x380.png',
      pixelRatio: 1,
    );
  });
}

void _noop() {}
