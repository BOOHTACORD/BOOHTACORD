import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/header/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/services/conversation_scroll_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';
import 'package:boohtacord_desktop/src/widgets/audio_device_check.dart';
import 'package:boohtacord_desktop/src/widgets/participant_volume/reset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    show MediaDevice, Room, RemoteParticipant;
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'uiux_2026/capture_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUp(() {
    ComposerDraftMemory.clear();
    ConversationScrollMemory.clear();
  });

  testWidgets('volume menu aligns with the avatar on macOS and Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final room = _PublishedScreenRoom();
    // ignore: invalid_use_of_internal_member
    final created = await RemoteParticipant.createFromInfo(
      room: room,
      info: lk.ParticipantInfo(
        sid: 'remote-sid',
        identity: 'remote-screen',
        name: 'Streamer',
        metadata: 'account:account-2',
        tracks: [
          lk.TrackInfo(
            sid: 'screen-sid',
            type: lk.TrackType.VIDEO,
            source: lk.TrackSource.SCREEN_SHARE,
            muted: false,
          ),
        ],
      ),
    );
    room.members['remote-screen'] = created.participant;
    final state = _PublishedScreenState(room);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(
      find.text('${_PortraitApi.voiceChannel.name} · 2 участника'),
      findsOneWidget,
    );
    expect(created.participant.videoTrackPublications.single.track, isNull);
    expect(
      find.widgetWithText(OutlinedButton, 'Смотреть экран'),
      findsOneWidget,
    );
    final remoteCard = find.byKey(
      const ValueKey('voice-participant-card:remote-sid'),
    );
    final remoteAvatar = find.descendant(
      of: remoteCard,
      matching: find.byType(AuthenticatedAvatar),
    );
    final volumeMenu = find.descendant(
      of: remoteCard,
      matching: find.byTooltip('Настройки громкости Streamer'),
    );
    expect(volumeMenu, findsOneWidget);
    expect(
      tester.getRect(volumeMenu).center.dy,
      lessThanOrEqualTo(tester.getRect(remoteAvatar).top + 8),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();
    final androidCard = find.byKey(
      const ValueKey('voice-participant-card:remote-sid'),
    );
    final androidAvatar = find.descendant(
      of: androidCard,
      matching: find.byType(AuthenticatedAvatar),
    );
    final androidVolumeMenu = find.descendant(
      of: androidCard,
      matching: find.byTooltip('Настройки громкости Streamer'),
    );
    expect(androidVolumeMenu, findsOneWidget);
    expect(
      tester.getRect(androidVolumeMenu).center.dy,
      lessThanOrEqualTo(tester.getRect(androidAvatar).top + 8),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Смотреть экран'));
    await tester.pump();
    expect(state.selectedScreen, 'remote-screen');
    expect(find.text('Подключаемся к демонстрации…'), findsOneWidget);
    expect(find.textContaining('Демонстрация завершена.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await tester.runAsync(() => room.dispose());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'mobile edge swipes open and close both workspace panels (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final state = AppState(_PortraitApi());
        await state.initialize();
        state.selectedChannel = _PortraitApi.channel;
        state.voiceChannel = _PortraitApi.voiceChannel;
        state.voicePhase = VoicePhase.connected;
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final composer = find.byType(TextField).first;
        await tester.tap(composer);
        await tester.pump();
        final returnFocus = FocusManager.instance.primaryFocus;
        expect(returnFocus, isNotNull);
        await tester.tap(find.byTooltip('Открыть навигацию'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);
        expect(FocusManager.instance.primaryFocus, same(returnFocus));
        expect(state.voicePhase, VoicePhase.connected);
        expect(state.voiceChannel, _PortraitApi.voiceChannel);

        await tester.tap(find.byTooltip('Открыть навигацию'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);
        expect(FocusManager.instance.primaryFocus, same(returnFocus));
        expect(state.voicePhase, VoicePhase.connected);
        expect(state.voiceChannel, _PortraitApi.voiceChannel);
        returnFocus?.unfocus();
        await tester.pumpAndSettle();

        await tester.dragFrom(const Offset(0, 220), const Offset(140, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);
        expect(state.voicePhase, VoicePhase.connected);
        expect(state.voiceChannel, _PortraitApi.voiceChannel);

        await tester.dragFrom(const Offset(0, 220), const Offset(140, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('workspace-channel-row:channel-1')),
        );
        await tester.pumpAndSettle();
        expect(state.selectedChannel, _PortraitApi.channel);
        expect(state.voiceChannel, _PortraitApi.voiceChannel);
        expect(state.voicePhase, VoicePhase.connected);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        await tester.dragFrom(const Offset(180, 220), const Offset(-120, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        await tester.dragFrom(const Offset(389, 220), const Offset(-140, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть участников'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        expect(find.byTooltip('Закрыть участников'), findsNothing);

        await tester.dragFrom(const Offset(220, 220), const Offset(120, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть участников'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'mobile message swipes reply and pull down refreshes history (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final api = _PortraitApi(
          withHistory: true,
          historyCount: 2,
          includeDirectMessage: true,
        );
        final state = AppState(api);
        await state.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textRow = find.text('Последнее сообщение');
        await tester.dragFrom(tester.getCenter(textRow), const Offset(95, 0));
        await tester.pumpAndSettle();
        expect(find.text('Ответ для @Участник'), findsOneWidget);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        final beforeTextRefresh = api.messagePageCalls;
        await tester.drag(
          find.byKey(const ValueKey('text-channel-messages')),
          const Offset(0, 280),
        );
        await tester.pumpAndSettle();
        expect(api.messagePageCalls, greaterThan(beforeTextRefresh));

        await state.openDirectConversation(state.directMessages.single);
        await tester.pumpAndSettle();
        await tester.dragFrom(
          tester.getCenter(find.text('Исходное личное сообщение')),
          const Offset(95, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ответ для Собеседник'), findsOneWidget);
        final beforeDirectRefresh = api.directMessagePageCalls;
        await tester.drag(
          find.text('Исходное личное сообщение'),
          const Offset(0, 280),
        );
        await tester.pumpAndSettle();
        expect(api.directMessagePageCalls, greaterThan(beforeDirectRefresh));

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'TEXT and DM message action menus expose touch-sized semantics (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final state = AppState(
          _PortraitApi(
            withHistory: true,
            historyCount: 2,
            includeDirectMessage: true,
          ),
        );
        await state.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> expectTouchAction(Finder control) async {
          final rect = tester.getRect(control);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(find.bySemanticsLabel('Действия с сообщением'), findsWidgets);
          await tester.tap(control);
          await tester.pumpAndSettle();
          final replyItem = find.ancestor(
            of: find.text('Ответить').last,
            matching: find.byType(PopupMenuItem<String>),
          );
          expect(replyItem, findsOneWidget);
          expect(
            tester.widget<PopupMenuItem<String>>(replyItem).height,
            greaterThanOrEqualTo(48),
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }

        await expectTouchAction(find.byTooltip('Действия с сообщением').first);
        await state.openDirectConversation(state.directMessages.single);
        await tester.pumpAndSettle();
        await expectTouchAction(find.byTooltip('Действия с сообщением').last);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('mobile PTT dock transmits only while mic is held', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..voiceChannel = _PortraitApi.voiceChannel
      ..selectedChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.connected
      ..audioActivationMode = AudioActivationMode.ptt;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ptt = find.byTooltip('Удерживайте, чтобы говорить');
    expect(ptt, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(ptt));
    await tester.pump();
    expect(state.pushToTalkPressed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(state.pushToTalkPressed, isFalse);

    final cancelledGesture = await tester.startGesture(
      tester.getCenter(ptt),
      pointer: 7,
    );
    await tester.pump();
    expect(state.pushToTalkPressed, isTrue);
    await cancelledGesture.cancel();
    await tester.pump();
    expect(state.pushToTalkPressed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('TEXT composer and connected voice controls stay above the IME', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding();
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi(withHistory: true));
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..voiceChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.connected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Написать сообщение…',
    );
    await tester.enterText(composer, 'Черновик перед открытием клавиатуры');
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    const keyboardTop = 844.0 - 280;
    final composerRect = tester.getRect(
      find.byKey(const ValueKey('text-composer-wrap')),
    );
    final voiceDockRect = tester.getRect(
      find.byKey(const ValueKey('mobile-voice-dock')),
    );
    expect(composerRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(voiceDockRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(find.byTooltip('Выключить микрофон'), findsOneWidget);
    expect(find.byTooltip('Выйти из голосового канала'), findsOneWidget);
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'Черновик перед открытием клавиатуры',
    );
    expect(state.selectedChannel?.id, _PortraitApi.channel.id);
    expect(state.voiceChannel, _PortraitApi.voiceChannel);
    expect(state.voicePhase, VoicePhase.connected);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('restores a text-channel draft after switching channels', (
    tester,
  ) async {
    final secondChannel = GuildChannel(
      id: 'channel-2',
      name: 'второй',
      kind: ChannelKind.text,
      admissionClosed: false,
      unreadCount: 0,
      mentionCount: 0,
    );
    final state = AppState(_PortraitApi(extraVoiceChannels: [secondChannel]));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Написать сообщение…',
    );
    await tester.enterText(composer, 'неотправленный текст');
    await tester.pump();
    await state.selectChannel(secondChannel);
    await tester.pumpAndSettle();
    expect(state.selectedChannel?.id, 'channel-2');
    expect(find.text('второй'), findsOneWidget);
    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);

    await state.selectChannel(_PortraitApi.channel);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'неотправленный текст',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('workspace resize preserves the channel scroll and voice state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 30));
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..voiceChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.connected;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final messageList = find.byKey(const ValueKey('text-channel-messages'));
    double messageScrollOffset() => tester
        .state<ScrollableState>(
          find
              .descendant(of: messageList, matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;

    await tester.drag(messageList, const Offset(0, 420));
    await tester.pumpAndSettle();
    final desktopOffset = messageScrollOffset();
    expect(desktopOffset, greaterThan(0));
    expect(
      tester
          .state<ScrollableState>(
            find
                .descendant(of: messageList, matching: find.byType(Scrollable))
                .first,
          )
          .position
          .extentAfter,
      greaterThan(48),
    );
    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Написать сообщение…',
    );
    await tester.enterText(composer, 'Черновик после resize');
    await tester.pump();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(state.selectedChannel?.id, _PortraitApi.channel.id);
    expect(state.voiceChannel, _PortraitApi.voiceChannel);
    expect(state.voicePhase, VoicePhase.connected);
    expect(messageScrollOffset(), closeTo(desktopOffset, 24));
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'Черновик после resize',
    );
    expect(find.byTooltip('Выйти из голосового канала'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'macOS app resize preserves native editing across stats rebuilds',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final state = AppState(_PortraitApi());
      await state.initialize();
      state
        ..selectedChannel = _PortraitApi.channel
        ..voiceChannel = _PortraitApi.voiceChannel
        ..voicePhase = VoicePhase.listener;
      await tester.pumpWidget(BoohtacordApp(state: state));
      await tester.pumpAndSettle();
      final composer = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Написать сообщение…',
      );
      await tester.showKeyboard(composer);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Native draft',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Native draft',
      );
      expect(
        ComposerDraftMemory.load<ChatMessage>(
          state.user!.accountId,
          ComposerDraftKind.channel,
          _PortraitApi.channel.id,
        )?.body,
        'Native draft',
      );
      for (final size in [
        const Size(801, 949),
        const Size(1440, 900),
        const Size(800, 900),
      ]) {
        tester.view.physicalSize = size;
        // Real stats notifications also rebuild BoohtacordApp during native resize.
        state.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'Native draft',
        );
        expect(state.voicePhase, VoicePhase.listener);
        expect(state.selectedChannel?.id, _PortraitApi.channel.id);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'shows a server-authored text channel description in its header',
    (tester) async {
      final state = AppState(_PortraitApi());
      await state.initialize();
      state.selectedChannel = const GuildChannel(
        id: 'channel-1',
        name: 'общий',
        description: 'Общение на любые темы',
        kind: ChannelKind.text,
        admissionClosed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Общение на любые темы'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('opens native audio settings and processing controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final scan = Completer<List<MediaDevice>>();
    final refreshScan = Completer<List<MediaDevice>>();
    var scanCount = 0;
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () {
        scanCount++;
        if (scanCount == 1) return scan.future;
        return refreshScan.future;
      },
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Настройки аудио'), findsOneWidget);
    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Микрофон'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Динамик'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('Микрофон'), findsOneWidget);
    expect(find.text('Динамик'), findsOneWidget);
    expect(find.text('Ищем устройства…'), findsNWidgets(2));
    expect(find.text('Микрофоны не найдены'), findsNothing);
    scan.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.text('Микрофоны не найдены'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Динамики не найдены'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('Ищем устройства…'), findsNothing);
    expect(find.text('Микрофоны не найдены'), findsOneWidget);
    expect(find.text('Динамики не найдены'), findsOneWidget);
    expect(state.audioDevicesLoading, isFalse);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere(
            (button) => button.tooltip == 'Обновить список устройств',
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Обновить список устройств'));
    await tester.pump();
    expect(scanCount, 2);
    expect(state.audioDevicesLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere(
            (button) => button.tooltip == 'Обновить список устройств',
          )
          .onPressed,
      isNull,
    );
    refreshScan.completeError(StateError('scan failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.audioDeviceScanFailed, isTrue);
    expect(find.text('Список недоступен'), findsNWidgets(2));
    expect(find.text('Микрофоны не найдены'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Активация микрофона'),
      audioScrollable,
      const Offset(0, 160),
    );
    expect(find.text('Активация микрофона'), findsOneWidget);
    expect(find.text('Назначить PTT-клавишу'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Дополнительно'),
      120,
      scrollable: audioScrollable,
    );
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Подавление эха'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('Подавление эха'), findsOneWidget);
    expect(find.textContaining('Нативный SDK не сообщает'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Назначить PTT-клавишу'),
      audioScrollable,
      const Offset(0, 160),
    );
    await tester.drag(audioList, const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назначить PTT-клавишу'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(state.pushToTalkKeyId, LogicalKeyboardKey.keyA.keyId);
    expect(find.textContaining('Клавиша PTT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('audio-activation-ptt')));
    await tester.pump();
    expect(state.audioActivationMode, AudioActivationMode.ptt);

    expect(find.byTooltip('Назад'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Design V2 audio settings lead with responsive device cards', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pump(const Duration(milliseconds: 100));

    final subtitle = find.text('Проверьте устройства перед разговором.');
    expect(subtitle, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(subtitle).didExceedMaxLines,
      isFalse,
    );
    final devices = find.byKey(const ValueKey('audio-settings-device-card'));
    final activation = find.byKey(
      const ValueKey('audio-settings-activation-card'),
    );
    final processing = find.byKey(
      const ValueKey('audio-settings-processing-card'),
    );
    expect(devices, findsOneWidget);
    expect(activation, findsOneWidget);
    expect(
      tester.getTopLeft(devices).dy,
      lessThan(tester.getTopLeft(activation).dy),
    );
    expect(tester.getSize(devices).height, greaterThanOrEqualTo(282));
    expect(
      (tester.widget<Container>(devices).decoration! as BoxDecoration).color,
      GcColors.surface,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('audio-device-control-Микрофон')))
          .height,
      44,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('audio-device-control-Динамик')))
          .height,
      44,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('audio-settings-activation-segment')),
          )
          .height,
      greaterThanOrEqualTo(46),
    );
    final audioScrollable = find.descendant(
      of: find.byKey(const ValueKey('audio-settings-list')),
      matching: find.byType(Scrollable),
    );
    final shortcuts = find.byKey(
      const ValueKey('audio-settings-shortcuts-card'),
    );
    final advanced = find.byKey(
      const PageStorageKey('audio-settings-advanced'),
    );
    await tester.scrollUntilVisible(advanced, 160, scrollable: audioScrollable);
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      shortcuts,
      160,
      scrollable: audioScrollable,
    );
    final shortcutsLeft = tester.getTopLeft(shortcuts).dx;
    expect(
      tester.getTopLeft(find.text('Микрофон').last).dx,
      closeTo(shortcutsLeft + 25, 1),
    );
    final shortcutAssign = tester.getTopRight(
      find.ancestor(
        of: find.text('Назначить').first,
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(shortcutAssign.dx, greaterThan(shortcutsLeft + 500));
    await tester.scrollUntilVisible(
      processing,
      160,
      scrollable: audioScrollable,
    );
    expect(processing, findsOneWidget);
    expect(tester.getSize(processing).height, greaterThanOrEqualTo(272));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop audio settings provide a labeled close action', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Закрыть настройки аудио'), findsOneWidget);
    expect(find.byTooltip('Назад'), findsNothing);
    await tester.tap(find.byTooltip('Закрыть настройки аудио'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('playback volume reset is separate from microphone processing', (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final scenario in [
      (TargetPlatform.macOS, const Size(1440, 900)),
      (TargetPlatform.android, const Size(390, 844)),
    ]) {
      debugDefaultTargetPlatformOverride = scenario.$1;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.$2;
      final state = AppState(
        _PortraitApi(),
        audioDeviceLoader: () async => const [],
      );
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
      await tester.pumpAndSettle();

      final audioList = find.byKey(const ValueKey('audio-settings-list'));
      final scrollable = find.descendant(
        of: audioList,
        matching: find.byType(Scrollable),
      );
      final playbackCard = find.byKey(
        const ValueKey('audio-settings-playback-card'),
      );
      await tester.scrollUntilVisible(
        playbackCard,
        140,
        scrollable: scrollable,
      );

      final processingCard = find.byKey(
        const ValueKey('audio-settings-processing-card'),
      );
      final reset = find.byType(AudioVolumeReset);
      expect(playbackCard, findsOneWidget);
      expect(find.text('Воспроизведение'), findsOneWidget);
      expect(
        find.descendant(of: playbackCard, matching: reset),
        findsOneWidget,
      );
      expect(
        find.descendant(of: processingCard, matching: reset),
        findsNothing,
      );
      expect(find.text('Сбросить настройки аудио'), findsOneWidget);
      expect(find.text('Дополнительно'), findsOneWidget);
      expect(find.text('Диагностика качества голоса'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    }
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'audio processing keeps essentials visible and discloses advanced controls',
    (tester) async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final scenario in [
        (TargetPlatform.macOS, const Size(1440, 900)),
        (TargetPlatform.android, const Size(390, 844)),
      ]) {
        debugDefaultTargetPlatformOverride = scenario.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.$2;
        final state = AppState(
          _PortraitApi(),
          audioDeviceLoader: () async => const [],
        );
        await state.initialize();
        state.toggleWorkspacePanel(WorkspacePanel.audio);
        await tester.pumpWidget(
          MaterialApp(home: WorkspaceScreen(state: state)),
        );
        await tester.pumpAndSettle();

        final audioScrollable = find.descendant(
          of: find.byKey(const ValueKey('audio-settings-list')),
          matching: find.byType(Scrollable),
        );
        final advanced = find.byKey(
          const PageStorageKey('audio-settings-advanced'),
        );
        await tester.scrollUntilVisible(
          advanced,
          160,
          scrollable: audioScrollable,
        );
        expect(find.text('Дополнительно'), findsOneWidget);
        expect(find.text('Шумоподавление'), findsNothing);
        expect(find.text('Подавление эха'), findsNothing);
        expect(find.text('Диагностика качества голоса'), findsNothing);
        final processingBefore = state.audioProcessing;
        await tester.tap(find.text('Дополнительно'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Подавление эха'),
          160,
          scrollable: audioScrollable,
        );
        expect(
          find.text('Автоматическая регулировка усиления'),
          findsOneWidget,
        );
        expect(find.text('Подавление эха'), findsOneWidget);
        expect(find.text('Громкость микрофона: 100%'), findsOneWidget);
        expect(find.text('Шумоподавление'), findsOneWidget);
        expect(find.text('Диагностика обработки'), findsOneWidget);
        expect(find.text('Диагностика качества голоса'), findsOneWidget);
        expect(state.audioProcessing, processingBefore);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      }
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    },
  );

  testWidgets('compact Design V2 audio cards preserve mobile control sizes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pump(const Duration(milliseconds: 100));

    final subtitle = find.byKey(const ValueKey('audio-settings-intro'));
    expect(subtitle, findsOneWidget);
    expect(tester.widget<Text>(subtitle).maxLines, isNull);
    expect(
      tester.renderObject<RenderParagraph>(subtitle).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getTopLeft(subtitle).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('audio-settings-device-card')),
            )
            .dy,
      ),
    );
    final devices = find.byKey(const ValueKey('audio-settings-device-card'));
    final activation = find.byKey(
      const ValueKey('audio-settings-activation-card'),
    );
    expect(devices, findsOneWidget);
    final audioScrollable = find.descendant(
      of: find.byKey(const ValueKey('audio-settings-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      activation,
      160,
      scrollable: audioScrollable,
    );
    expect(activation, findsOneWidget);
    expect(tester.getSize(devices).height, greaterThanOrEqualTo(346));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('audio-device-control-Микрофон')))
          .height,
      44,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('audio-device-control-Динамик')))
          .height,
      44,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('audio-settings-activation-segment')),
          )
          .height,
      50,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'audio activation and VAD expose web-equivalent semantics at compact width',
    (tester) async {
      final semantics = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final state = AppState(
        _PortraitApi(),
        audioDeviceLoader: () async => const [],
      );
      await state.initialize();
      await state.setAudioActivationMode(AudioActivationMode.vad);
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: WorkspaceScreen(state: state),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final audioScrollable = find.descendant(
        of: find.byKey(const ValueKey('audio-settings-list')),
        matching: find.byType(Scrollable),
      );
      final activationGroup = find.byKey(
        const ValueKey('audio-activation-mode-group'),
      );
      await tester.scrollUntilVisible(
        activationGroup,
        140,
        scrollable: audioScrollable,
      );
      expect(tester.getSemantics(activationGroup).label, 'Активация микрофона');
      final voiceMode = tester.getSemantics(
        find.byKey(const ValueKey('audio-activation-vad')),
      );
      expect(voiceMode.label, 'По голосу');
      expect(voiceMode.flagsCollection.isButton, isTrue);
      expect(voiceMode.flagsCollection.isSelected, Tristate.isTrue);

      final pttMode = find.byKey(const ValueKey('audio-activation-ptt'));
      await tester.ensureVisible(pttMode);
      await tester.pumpAndSettle();
      await tester.tap(pttMode);
      await tester.pumpAndSettle();
      expect(state.audioActivationMode, AudioActivationMode.ptt);
      final pushToTalkMode = tester.getSemantics(
        find.byKey(const ValueKey('audio-activation-ptt')),
      );
      expect(pushToTalkMode.label, 'По нажатию');
      expect(pushToTalkMode.flagsCollection.isButton, isTrue);
      expect(pushToTalkMode.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('audio-activation-vad')))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      final vadSlider = find.byKey(const ValueKey('microphone-vad-threshold'));
      await tester.scrollUntilVisible(
        vadSlider,
        140,
        scrollable: audioScrollable,
      );
      final vadSemantics = find
          .ancestor(of: vadSlider, matching: find.byType(Semantics))
          .first;
      expect(
        tester.getSemantics(vadSemantics).label,
        contains('Чувствительность'),
      );
      final vadControl = tester.widget<Slider>(vadSlider);
      expect(vadControl.semanticFormatterCallback?.call(-50), '-50 dBFS');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'large accessibility text keeps audio activation labels readable',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final state = AppState(
        _PortraitApi(),
        audioDeviceLoader: () async => const [],
      );
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.5)),
              child: WorkspaceScreen(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final audioScrollable = find.descendant(
        of: find.byKey(const ValueKey('audio-settings-list')),
        matching: find.byType(Scrollable),
      );
      final activationGroup = find.byKey(
        const ValueKey('audio-activation-mode-group'),
      );
      await tester.scrollUntilVisible(
        activationGroup,
        120,
        scrollable: audioScrollable,
      );

      final selector = find.byKey(
        const ValueKey('audio-settings-activation-segment'),
      );
      expect(tester.getSize(selector).height, greaterThan(50));
      for (final option in [
        (const ValueKey('audio-activation-vad'), 'По голосу'),
        (const ValueKey('audio-activation-ptt'), 'По нажатию'),
      ]) {
        final label = find.descendant(
          of: find.byKey(option.$1),
          matching: find.text(option.$2),
        );
        expect(label, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
          reason: '${option.$2} should not be truncated at 2.5× text scale',
        );
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'audio settings remain scrollable in landscape and short windows',
    (tester) async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final scenarios = [
        (TargetPlatform.android, const Size(852, 393)),
        (TargetPlatform.macOS, const Size(1100, 520)),
      ];
      for (final scenario in scenarios) {
        debugDefaultTargetPlatformOverride = scenario.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.$2;
        final state = AppState(
          _PortraitApi(),
          audioDeviceLoader: () async => const [],
        );
        await state.initialize();
        state.toggleWorkspacePanel(WorkspacePanel.audio);
        await tester.pumpWidget(
          MaterialApp(home: WorkspaceScreen(state: state)),
        );
        await tester.pumpAndSettle();

        final audioScrollable = find.descendant(
          of: find.byKey(const ValueKey('audio-settings-list')),
          matching: find.byType(Scrollable),
        );
        final microphone = find.byKey(
          const ValueKey('audio-device-control-Микрофон'),
        );
        final speaker = find.byKey(
          const ValueKey('audio-device-control-Динамик'),
        );
        expect(microphone, findsOneWidget);
        expect(speaker, findsOneWidget);
        if (scenario.$1 == TargetPlatform.android) {
          expect(
            tester.getRect(microphone).bottom,
            lessThanOrEqualTo(tester.getRect(speaker).top),
          );
        } else {
          expect(
            tester.getRect(microphone).right,
            lessThanOrEqualTo(tester.getRect(speaker).left),
          );
        }
        expect(tester.takeException(), isNull);

        final activationGroup = find.byKey(
          const ValueKey('audio-activation-mode-group'),
        );
        await tester.scrollUntilVisible(
          activationGroup,
          100,
          scrollable: audioScrollable,
        );
        expect(activationGroup, findsOneWidget);
        final playback = find.byKey(
          const ValueKey('audio-settings-playback-card'),
        );
        await tester.scrollUntilVisible(
          playback,
          100,
          scrollable: audioScrollable,
        );
        expect(playback, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      }
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('desktop audio activation modes support keyboard navigation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 640);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final voiceMode = find.byKey(const ValueKey('audio-activation-vad'));
    final pushToTalkMode = find.byKey(const ValueKey('audio-activation-ptt'));
    await tester.ensureVisible(voiceMode);
    await tester.pumpAndSettle();
    final voiceFocusFinder = find.descendant(
      of: voiceMode,
      matching: find.byType(Focus),
    );
    expect(voiceFocusFinder, findsWidgets);
    final voiceFocus = tester.widget<Focus>(voiceFocusFinder.first).focusNode!;
    voiceFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(voiceFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(state.audioActivationMode, AudioActivationMode.ptt);
    expect(
      tester.getSemantics(pushToTalkMode).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android audio settings configure PTT without a key binding', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final activationSegment = find.byKey(
      const ValueKey('audio-settings-activation-segment'),
    );
    final audioScrollable = find.descendant(
      of: find.byKey(const ValueKey('audio-settings-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      activationSegment,
      160,
      scrollable: audioScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Назначить PTT-клавишу'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('audio-activation-ptt')));
    await tester.pumpAndSettle();

    expect(state.audioActivationMode, AudioActivationMode.ptt);
    expect(state.audioActivationError, isNull);
    expect(find.text('Назначить PTT-клавишу'), findsNothing);
    expect(find.textContaining('Удерживайте кнопку микрофона'), findsOneWidget);
    expect(
      find.textContaining('Удерживайте назначенную клавишу'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('audio settings test the devices shown in their selectors', (
    tester,
  ) async {
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('input-1', 'USB microphone', 'audioinput', null),
        MediaDevice('output-1', 'USB speakers', 'audiooutput', null),
      ],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('audio-device-check')),
      160,
      scrollable: audioScrollable,
    );
    final check = tester.widget<AudioDeviceCheck>(
      find.byKey(const ValueKey('audio-device-check')),
    );
    expect(check.inputDeviceId, 'input-1');
    expect(check.inputDeviceLabel, 'USB microphone');
    expect(check.outputDeviceId, 'output-1');
    expect(check.outputDeviceLabel, 'USB speakers');
    expect(find.text('Проверить микрофон'), findsOneWidget);
    expect(find.text('Проверить динамик'), findsOneWidget);
    expect(
      find.text(
        'Проверка локальная: она не подтверждает слышимость у другого участника.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'audio device switching shows status and disables each selector',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final state = AppState(
        _PortraitApi(),
        audioDeviceLoader: () async => const [
          MediaDevice('input-1', 'USB microphone', 'audioinput', null),
          MediaDevice('output-1', 'USB speakers', 'audiooutput', null),
        ],
      );
      await state.initialize();
      state.audioDevices.audioInputSwitching = true;
      state.audioDevices.audioOutputSwitching = true;
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Переключаем микрофон…'), findsOneWidget);
      expect(find.text('Переключаем динамик…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('audio-device-switching-Микрофон')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('audio-device-switching-Динамик')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('audio-device-switching-Микрофон')),
            )
            .properties
            .liveRegion,
        isTrue,
      );
      final inputSelector = find.descendant(
        of: find.byKey(const ValueKey('audio-device-control-Микрофон')),
        matching: find.byType(DropdownButton<String>),
      );
      final outputSelector = find.descendant(
        of: find.byKey(const ValueKey('audio-device-control-Динамик')),
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        tester.widget<DropdownButton<String>>(inputSelector).onChanged,
        isNull,
      );
      expect(
        tester.widget<DropdownButton<String>>(outputSelector).onChanged,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Переключаем микрофон…'), findsOneWidget);
      expect(find.text('Переключаем динамик…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('shows named audio devices when the SDK has no default entry', (
    tester,
  ) async {
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('usb-mic', 'USB Microphone', 'audioinput', null),
        MediaDevice('bt-output', 'Bluetooth headphones', 'audiooutput', null),
      ],
    );
    await state.initialize();
    await state.refreshAudioDevices();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('USB Microphone'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Bluetooth headphones'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('USB Microphone'), findsOneWidget);
    expect(find.text('Bluetooth headphones'), findsOneWidget);
    expect(find.textContaining('Системный выбор'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('announces when the selected audio device disconnects', (
    tester,
  ) async {
    const warning =
        'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.';
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('mic-new', 'Built-in microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ],
    );
    await state.initialize();
    state.audioDeviceWarning = warning;
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('audio-device-warning')),
      160,
      scrollable: find.descendant(
        of: audioList,
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text(warning), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.key == const ValueKey('audio-device-warning') &&
            widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel matches web toolbar without a duplicate heading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-screen-title-focus')),
        matching: find.text('Настройки'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Открыть навигацию'), findsNothing);
    expect(find.byTooltip('Открыть участников'), findsNothing);
    expect(find.byTooltip('Назад'), findsNothing);
    expect(find.byTooltip('Закрыть настройки'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Закрыть настройки'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  for (final action in ['close', 'back', 'system Back']) {
    testWidgets('dirty profile $action asks before discarding edits', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(801, 949);
      addTearDown(tester.view.reset);
      final state = AppState(_PortraitApi());
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.profile);
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (context, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Отображаемое имя',
      );
      await tester.enterText(name, 'Unsaved profile');
      await tester.pump();
      if (action == 'system Back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(
          find.byTooltip(action == 'close' ? 'Закрыть настройки' : 'Назад'),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      expect(state.workspacePanel, WorkspacePanel.profile);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Unsaved profile',
      );
      await tester.tap(find.byTooltip('Закрыть настройки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти без сохранения'));
      await tester.pumpAndSettle();
      expect(state.workspacePanel, WorkspacePanel.none);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }

  testWidgets('dirty profile close cancels when the account changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(801, 949);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Отображаемое имя',
    );
    await tester.enterText(name, 'Unsaved profile');
    await tester.tap(find.byTooltip('Закрыть настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    state.profile = const OwnProfile(
      accountId: 'replacement-account',
      login: 'replacement',
      displayName: 'Replacement',
      role: 'MEMBER',
    );
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsNothing);
    expect(state.workspacePanel, WorkspacePanel.profile);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile close waits for an in-flight save', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(801, 949);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    state.profileSaving = true;
    state.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть настройки'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.profile);
    expect(find.text('Несохранённые изменения'), findsNothing);
    state.profileSaving = false;
    await tester.tap(find.byTooltip('Закрыть настройки'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel keeps Android Back and navigation actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-screen-title-focus')),
        matching: find.text('Настройки'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Назад'), findsOneWidget);
    expect(find.byTooltip('Открыть навигацию'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Назад')).left, lessThan(24));
    expect(
      tester.getRect(find.byTooltip('Открыть навигацию')).left,
      greaterThan(330),
    );
    expect(find.byTooltip('Открыть участников'), findsNothing);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('compact workspace header actions match web 44 px targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    for (final tooltip in ['Открыть навигацию', 'Открыть участников']) {
      expect(tester.getSize(find.byTooltip(tooltip)), const Size(44, 44));
    }

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel restores the opening keyboard focus on close', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    final openingFocus = FocusNode(debugLabel: 'workspace-panel-opener');
    addTearDown(openingFocus.dispose);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: openingFocus,
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) => WorkspaceScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    openingFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(openingFocus));

    state.toggleWorkspacePanel(WorkspacePanel.profile);
    await tester.pumpAndSettle();
    final profileFocus = tester
        .widget<Focus>(find.byKey(const ValueKey('profile-screen-title-focus')))
        .focusNode!;
    profileFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(profileFocus));

    state.toggleWorkspacePanel(WorkspacePanel.none);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(openingFocus));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('offers to reopen a local screen from the participant view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.screenSharePhase = ScreenSharePhase.sharing;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Все в сборе'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Смотреть экран'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Участник показывает экран'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice-participant-grid')),
      findsOneWidget,
    );
    final selfCard = find.byKey(const ValueKey('voice-participant-card:self'));
    expect(tester.getSize(selfCard).height, greaterThanOrEqualTo(160));
    expect(tester.getSize(selfCard).width, greaterThanOrEqualTo(160));
    final selfCardRect = tester.getRect(selfCard);
    final screenShareBadgeRect = tester.getRect(
      find.bySemanticsLabel('Участник показывает экран'),
    );
    expect(selfCardRect.contains(screenShareBadgeRect.topLeft), isTrue);
    expect(selfCardRect.contains(screenShareBadgeRect.bottomRight), isTrue);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(selfCard).width, greaterThanOrEqualTo(136));
    expect(tester.getSize(selfCard).height, greaterThanOrEqualTo(160));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('deafened participant status stays centered without truncating', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.deafened = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final status = find.text('Звук и микрофон выключены');
    final statusText = tester.widget<Text>(status);
    final card = find.byKey(const ValueKey('voice-participant-card:self'));
    expect(statusText.textAlign, TextAlign.center);
    expect(statusText.maxLines, isNull);
    expect(statusText.overflow, isNull);
    expect(
      tester.getRect(status).center.dx,
      closeTo(tester.getRect(card).center.dx, 0.1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows a retryable microphone-unavailable listener state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.listener;
    state.microphoneMuted = true;
    state.microphoneUnavailable = true;
    state.audioActivationMode = AudioActivationMode.vad;

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Микрофон недоступен'), findsNWidgets(2));
    expect(find.textContaining('подключены как слушатель'), findsOneWidget);
    expect(find.byTooltip('Повторить включение микрофона'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Android PTT listener guidance does not request a key', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.voiceChannel
      ..voiceChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.listener
      ..microphoneMuted = true
      ..microphoneUnavailable = true
      ..audioActivationMode = AudioActivationMode.ptt;

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Удерживайте кнопку микрофона'), findsOneWidget);
    expect(find.textContaining('назначенную PTT-клавишу'), findsNothing);
    expect(find.text('Назначить PTT-клавишу'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('announces prejoin roster loading and errors as live status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    state
      ..voiceRosters = null
      ..voiceRosterError = null
      ..notifyListeners();
    await tester.pump();
    final loadingStatus = find.text('Проверяем, кто сейчас в комнате…');
    expect(loadingStatus, findsOneWidget);
    expect(find.text('Голосовой канал · проверяем состав'), findsOneWidget);
    expect(
      tester.getSemantics(loadingStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    state
      ..voiceRosterError = 'Нет связи со списком голосовых каналов.'
      ..notifyListeners();
    await tester.pump();
    final errorStatus = find.text('Не удалось обновить состав комнаты.');
    expect(errorStatus, findsOneWidget);
    expect(find.text('Голосовой канал · состав недоступен'), findsOneWidget);
    expect(
      tester.getSemantics(errorStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    state
      ..voiceRosterError = null
      ..voiceRosters = const [
        VoiceRoomRoster(channelId: 'voice-1', participants: []),
      ];
    // This synthetic assignment represents a newly accepted roster snapshot.
    state.voiceRoster.phase = VoiceRosterPhase.fresh;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · пока пусто'), findsOneWidget);

    state
      ..voiceRosters = const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Собеседник',
              screenSharing: false,
              microphoneMuted: true,
            ),
          ],
        ),
      ]
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · сейчас: 1'), findsOneWidget);

    state
      ..selectedChannel = const GuildChannel(
        id: 'voice-1',
        name: 'голосовой',
        kind: ChannelKind.voice,
        admissionClosed: true,
      )
      ..voiceRosters = null
      ..voiceRosterError = 'Нет связи со списком голосовых каналов.'
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · состав недоступен'), findsOneWidget);
    final closedNotice = find.text(
      'Вход в этот канал закрыт администратором. Отзыв media-доступа ещё подтверждается.',
    );
    expect(closedNotice, findsOneWidget);
    expect(
      tester.getSemantics(closedNotice).getSemanticsData().role,
      SemanticsRole.status,
    );
    expect(
      find.text(
        'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
      ),
      findsNothing,
    );
    expect(find.text('Подключиться без микрофона'), findsNothing);

    state
      ..voiceChannel = state.selectedChannel
      ..voicePhase = VoicePhase.connected
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Выйти из голосового канала'), findsOneWidget);
    expect(find.text('Все в сборе'), findsNothing);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('exposes text conversation errors with alert semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..error = 'Не удалось загрузить историю.';

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final error = find.text('Не удалось загрузить историю.');
    expect(error, findsOneWidget);
    final alert = find.ancestor(
      of: error,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.alert,
      ),
    );
    expect(
      tester.getSemantics(alert).getSemanticsData().role,
      SemanticsRole.alert,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('exposes Android conversation errors as polite live regions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..error = 'Не удалось загрузить историю.';

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final error = find.text('Не удалось загрузить историю.');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.alert,
        ),
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows the voice roster before joining the room', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final api = _PortraitApi(
      voiceRosters: const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: true,
              microphoneMuted: true,
            ),
          ],
        ),
      ],
    );
    final state = AppState(api);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Вы не подключены'), findsOneWidget);
    expect(
      find.text(
        'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
      ),
      findsOneWidget,
    );
    expect(find.text('Последний состав: 1'), findsOneWidget);
    expect(find.text('Мика'), findsNWidgets(2));
    expect(find.byTooltip('Показывает экран'), findsNWidgets(2));
    expect(find.text('Идёт трансляция'), findsOneWidget);
    final navigationMic = find.descendant(
      of: find.byTooltip('Микрофон выключен'),
      matching: find.byIcon(Icons.mic_off_outlined),
    );
    expect(navigationMic, findsNWidgets(2));
    expect(
      tester.widgetList<Icon>(navigationMic).map((icon) => icon.color),
      everyElement(GcColors.text),
    );
    final avatars = tester
        .widgetList<AuthenticatedAvatar>(find.byType(AuthenticatedAvatar))
        .where((avatar) => avatar.name == 'Мика');
    expect(avatars, hasLength(2));
    expect(avatars.map((avatar) => avatar.radius), everyElement(12));
    expect(
      avatars.map((avatar) => avatar.backgroundColor),
      everyElement(GcColors.avatarBlue),
    );
    expect(
      tester.widgetList<Icon>(find.byIcon(Icons.desktop_windows_outlined)),
      hasLength(2),
    );
    expect(state.voicePhase, VoicePhase.idle);
    expect(state.voiceChannel, isNull);

    state.voicePhase = VoicePhase.joining;
    state.notifyListeners();
    await tester.pump();

    expect(find.text('Подключаемся к голосовой комнате'), findsOneWidget);
    final joiningTitle = find.ancestor(
      of: find.text('Подключаемся к голосовой комнате'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(joiningTitle, findsOneWidget);
    expect(
      tester.widget<Semantics>(joiningTitle).properties.label,
      'Подключаемся к голосовой комнате',
    );
    expect(find.text('Соединение устанавливается.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Подключаемся…'),
          )
          .onPressed,
      isNull,
    );

    state.error = 'Не удалось подключиться к голосовому каналу';
    state.notifyListeners();
    await tester.pump();
    expect(find.text(state.error!), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(state.error!),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('text workspace geometry matches Design V2 breakpoints', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(withHistory: true, includeDirectMessage: true),
    );
    await state.initialize();
    state.messages = [
      ChatMessage(
        id: 'design-v2-first',
        channelId: _PortraitApi.channel.id,
        authorId: 'account-1',
        body: 'Первое сообщение Design V2',
        createdAt: DateTime.utc(2026, 9, 25, 12),
        deleted: false,
        revision: 1,
      ),
      ChatMessage(
        id: 'design-v2-second',
        channelId: _PortraitApi.channel.id,
        authorId: 'account-2',
        body: 'Второе сообщение Design V2',
        createdAt: DateTime.utc(2026, 9, 25, 12, 1),
        deleted: false,
        revision: 1,
      ),
    ];
    state.selectedChannel = _PortraitApi.channel;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final viewport in [
      (size: const Size(320, 640), mainLeft: 0.0, mainWidth: 320.0),
      (size: const Size(360, 800), mainLeft: 0.0, mainWidth: 360.0),
      (size: const Size(375, 812), mainLeft: 0.0, mainWidth: 375.0),
      (size: const Size(390, 844), mainLeft: 0.0, mainWidth: 390.0),
      (size: const Size(430, 932), mainLeft: 0.0, mainWidth: 430.0),
      (size: const Size(600, 900), mainLeft: 0.0, mainWidth: 600.0),
      (size: const Size(840, 390), mainLeft: 0.0, mainWidth: 840.0),
      (size: const Size(1024, 768), mainLeft: 280.0, mainWidth: 744.0),
      (size: const Size(1280, 800), mainLeft: 280.0, mainWidth: 752.0),
      (size: const Size(1440, 900), mainLeft: 280.0, mainWidth: 912.0),
      (size: const Size(1920, 1080), mainLeft: 280.0, mainWidth: 1392.0),
    ]) {
      tester.view.physicalSize = viewport.size;
      await tester.pumpAndSettle();

      final compact = viewport.size.width < 1024;
      final header = tester.getRect(
        find.byKey(const ValueKey('workspace-header')),
      );
      expect(header.height, compact ? 56 : 64);
      final main = tester.getRect(
        find.byKey(const ValueKey('workspace-main-surface')),
      );
      expect(main.left, viewport.mainLeft);
      expect(main.width, viewport.mainWidth);
      expect(state.selectedChannel?.id, _PortraitApi.channel.id);
      expect(state.messages, hasLength(2));
      expect(main.left, greaterThanOrEqualTo(0));
      expect(main.right, lessThanOrEqualTo(viewport.size.width));
      if (!compact) {
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('workspace-channel-row:channel-1')),
              )
              .height,
          36,
        );
      }

      final messages = tester.widget<ListView>(
        find.byKey(const ValueKey('text-channel-messages')),
      );
      expect(
        messages.padding,
        compact
            ? const EdgeInsets.fromLTRB(12, 16, 12, 8)
            : EdgeInsets.fromLTRB(
                viewport.size.width < 1280 ? 20 : 24,
                20,
                viewport.size.width < 1280 ? 20 : 24,
                12,
              ),
      );
      final messageAvatars = tester.widgetList<AuthenticatedAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('text-channel-messages')),
          matching: find.byType(AuthenticatedAvatar),
        ),
      );
      expect(messageAvatars, hasLength(2));
      expect(
        messageAvatars.map((avatar) => avatar.radius),
        everyElement(compact ? 16 : 18),
      );
      final firstMessageRow = find.ancestor(
        of: find.text('Первое сообщение Design V2'),
        matching: find.byWidgetPredicate(
          (widget) => widget is KeyedSubtree && widget.key is GlobalKey,
        ),
      );
      final secondMessageRow = find.ancestor(
        of: find.text('Второе сообщение Design V2'),
        matching: find.byWidgetPredicate(
          (widget) => widget is KeyedSubtree && widget.key is GlobalKey,
        ),
      );
      expect(
        tester.getTopLeft(secondMessageRow.first).dy -
            tester.getBottomLeft(firstMessageRow.first).dy,
        compact ? 20 : 24,
      );
      final composer = tester.widget<Container>(
        find.byKey(const ValueKey('text-composer-wrap')),
      );
      final composerHorizontal = compact
          ? 8.0
          : viewport.size.width < 1280
          ? 20.0
          : 24.0;
      expect(
        composer.padding,
        compact
            ? const EdgeInsets.all(8)
            : EdgeInsets.fromLTRB(
                composerHorizontal,
                8,
                composerHorizontal,
                16,
              ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('text-composer-wrap'))).height,
        compact ? 70 : 98,
      );
      expect(
        find.text('До 25 МБ на файл'),
        compact ? findsNothing : findsOneWidget,
      );
    }

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 360.0, 375.0, 390.0, 430.0, 600.0, 840.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('mobile-sidebar'))).width,
        width < 360 ? width - 40 : 320,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('workspace-channel-row:channel-1')),
            )
            .height,
        44,
      );
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть навигацию'));
    await tester.pumpAndSettle();

    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpAndSettle();
    expect(state.selectedDirectMessage, isNotNull);
    expect(state.directMessageHistory, isNotEmpty);
    final selectedDirectMessageId = state.selectedDirectMessage!.id;
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('direct-message-messages')),
          )
          .padding,
      const EdgeInsets.fromLTRB(12, 16, 12, 8),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('direct-message-composer-wrap')),
          )
          .padding,
      const EdgeInsets.all(8),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      70,
    );
    expect(find.text('До 25 МБ на файл'), findsNothing);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('direct-message-messages')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 20, 24, 12),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('direct-message-composer-wrap')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 8, 24, 16),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      98,
    );
    expect(find.text('До 25 МБ на файл'), findsOneWidget);

    for (final viewport in [
      const Size(320, 640),
      const Size(375, 812),
      const Size(390, 844),
      const Size(430, 932),
      const Size(600, 900),
      const Size(840, 390),
      const Size(1024, 768),
      const Size(1280, 800),
      const Size(1440, 900),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      expect(state.selectedDirectMessage?.id, selectedDirectMessageId);
      expect(state.directMessageHistory, isNotEmpty);
      final composerRect = tester.getRect(
        find.byKey(const ValueKey('direct-message-composer-wrap')),
      );
      expect(composerRect.left, greaterThanOrEqualTo(0));
      expect(composerRect.right, lessThanOrEqualTo(viewport.width));
      expect(composerRect.bottom, lessThanOrEqualTo(viewport.height));
      expect(tester.takeException(), isNull);
    }

    const longDisplayName =
        'ОченьДлинноеИмяПользователяБезПробеловДляПроверкиЭллипсиса';
    await state.openDirectConversation(
      const DirectConversation(
        id: 'dm-1',
        participantId: 'account-2',
        displayName: longDisplayName,
        unreadCount: 0,
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final longTitle = tester.widget<Text>(
      find.descendant(
        of: find.byType(WorkspaceHeader),
        matching: find.text(longDisplayName),
      ),
    );
    expect(longTitle.maxLines, 1);
    expect(longTitle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('channel categories collapse with a highlighted compact header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.channel;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(
      const ValueKey('workspace-category-header:category-1'),
    );
    expect(header, findsOneWidget);
    final headerContainer = tester.widget<Container>(header);
    expect(headerContainer.decoration, isNull);
    expect(
      find.byKey(const ValueKey('workspace-channel-row:channel-1')),
      findsOneWidget,
    );
    final menuVisibility = find.byKey(
      const ValueKey('topology-object-menu-visibility:channel-1'),
    );
    expect(tester.widget<Visibility>(menuVisibility).visible, isFalse);
    final channelFocus = tester.widget<FocusableActionDetector>(
      find.byKey(const ValueKey('workspace-channel-focus:channel-1')),
    );
    channelFocus.onShowFocusHighlight!(true);
    await tester.pump();
    expect(tester.widget<Visibility>(menuVisibility).visible, isTrue);
    channelFocus.onShowFocusHighlight!(false);
    await tester.pump();
    expect(tester.widget<Visibility>(menuVisibility).visible, isFalse);
    final categoryToggle = tester.widget<InkWell>(
      find.byKey(const ValueKey('workspace-category-toggle:category-1')),
    );
    expect(categoryToggle.hoverColor, Colors.transparent);
    expect(categoryToggle.highlightColor, Colors.transparent);
    expect(categoryToggle.splashColor, Colors.transparent);
    expect(categoryToggle.mouseCursor, isA<WidgetStateMouseCursor>());
    final categoryCursor =
        categoryToggle.mouseCursor! as WidgetStateMouseCursor;
    expect(
      categoryCursor.resolve(<WidgetState>{WidgetState.hovered}),
      SystemMouseCursors.click,
    );
    expect(categoryCursor.resolve(<WidgetState>{}), SystemMouseCursors.basic);
    expect(find.byTooltip('Свернуть раздел Текстовые каналы'), findsNothing);
    await tester.tap(find.text('ТЕКСТОВЫЕ КАНАЛЫ'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-channel-row:channel-1')),
      findsNothing,
    );
    expect(find.byTooltip('Развернуть раздел Текстовые каналы'), findsNothing);
    await tester.tap(find.text('ТЕКСТОВЫЕ КАНАЛЫ'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-channel-row:channel-1')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice prejoin matches web desktop spacing and card padding', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('voice-prejoin-card'));
    expect(
      tester.widget<Container>(cardFinder).padding,
      const EdgeInsets.all(44),
    );
    final scrollFinder = find
        .ancestor(of: cardFinder, matching: find.byType(SingleChildScrollView))
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).padding,
      const EdgeInsets.all(72),
    );
    final icon = tester.widget<Container>(
      find.byKey(const ValueKey('voice-prejoin-icon')),
    );
    final iconDecoration = icon.decoration! as BoxDecoration;
    expect(iconDecoration.color, GcColors.raised);
    expect(
      iconDecoration.border,
      Border.fromBorderSide(const BorderSide(color: GcColors.control)),
    );
    expect(
      tester.widget<Text>(find.text('Вы не подключены')).style?.fontSize,
      24,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice prejoin matches mobile padding without header overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('voice-prejoin-card'));
    expect(
      tester.widget<Container>(cardFinder).padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
    final scrollFinder = find
        .ancestor(of: cardFinder, matching: find.byType(SingleChildScrollView))
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).padding,
      const EdgeInsets.all(16),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice dock reports accurate microphone actions in all states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final room = _PublishedScreenRoom();
    final state = _PublishedScreenState(room);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.audioActivationMode = AudioActivationMode.vad;
    state.microphoneMuted = false;
    state.microphoneUnavailable = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Голос подключён'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(find.byIcon(Icons.headphones_outlined), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Голос подключён')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      find.text('${state.voiceChannel!.name} · 1 участник'),
      findsOneWidget,
    );
    final dock = find.byKey(const ValueKey('voice-dock'));
    expect(
      find.descendant(
        of: dock,
        matching: find.byIcon(Icons.signal_cellular_alt_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: dock,
        matching: find.bySemanticsLabel(
          'Качество соединения: Нет данных · ping —',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label ==
                'Голос подключён · ${state.voiceChannel!.name}',
      ),
      findsOneWidget,
    );
    final qualitySemantics = tester
        .widgetList<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'Качество соединения: Нет данных · ping —',
          ),
        )
        .toList();
    expect(qualitySemantics, isNotEmpty);
    expect(
      qualitySemantics.every((item) => item.properties.liveRegion != true),
      isTrue,
    );
    expect(find.text('В голосовом канале'), findsNothing);
    final microphoneButton = tester.getSemantics(
      find.bySemanticsLabel('Выключить микрофон').first,
    );
    expect(microphoneButton.label, 'Выключить микрофон');
    expect(microphoneButton.flagsCollection.isToggled, Tristate.isTrue);
    state.microphoneUnavailable = true;
    state.notifyListeners();
    await tester.pump();
    final unavailableMicrophoneButton = tester.getSemantics(
      find.byTooltip('Микрофон недоступен · повторить включение'),
    );
    expect(
      unavailableMicrophoneButton.label,
      'Повторить включение микрофона — микрофон недоступен',
    );
    expect(
      unavailableMicrophoneButton.getSemanticsData().hasAction(
        SemanticsAction.tap,
      ),
      isTrue,
    );
    state.microphoneUnavailable = false;
    state.audioActivationMode = AudioActivationMode.ptt;
    state.notifyListeners();
    await tester.pump();
    final pushToTalkMicrophoneButton = tester.getSemantics(
      find.byTooltip('Микрофон управляется push-to-talk'),
    );
    expect(
      pushToTalkMicrophoneButton.label,
      'Микрофон управляется push-to-talk',
    );
    expect(
      pushToTalkMicrophoneButton.getSemanticsData().hasAction(
        SemanticsAction.tap,
      ),
      isFalse,
    );
    state.audioActivationMode = AudioActivationMode.vad;
    state.notifyListeners();
    await tester.pump();
    final deafenSemantics = tester.getSemantics(
      find.byTooltip('Выключить удалённый звук'),
    );
    expect(deafenSemantics.label, 'Выключить удалённый звук');
    expect(deafenSemantics.flagsCollection.isToggled, Tristate.isFalse);
    await tester.tap(find.byTooltip('Ещё настройки голоса'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<String>>(
            find.widgetWithText(
              CheckedPopupMenuItem<String>,
              'Сигнал новых трансляций',
            ),
          )
          .checked,
      isTrue,
    );
    await tester.tap(find.text('Сигнал новых трансляций'));
    await tester.pumpAndSettle();
    expect(state.voiceStreamSoundEnabled, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'voice-screen-start-sound:v1',
      ),
      isFalse,
    );
    await tester.tap(find.byTooltip('Ещё настройки голоса'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<String>>(
            find.widgetWithText(
              CheckedPopupMenuItem<String>,
              'Сигнал новых трансляций',
            ),
          )
          .checked,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Начать демонстрацию экрана'), findsNWidgets(2));
    final startScreenShareSemantics = tester.getSemantics(
      find.byTooltip('Начать демонстрацию экрана').first,
    );
    expect(startScreenShareSemantics.label, 'Начать демонстрацию экрана');
    expect(
      startScreenShareSemantics.getSemanticsData().hasAction(
        SemanticsAction.tap,
      ),
      isTrue,
    );
    await tester.tap(find.byTooltip('Начать демонстрацию экрана').first);
    await tester.pump();
    expect(find.text('Демонстрация экрана'), findsOneWidget);
    expect(find.text('Качество трансляции'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    state.voicePhase = VoicePhase.joining;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Подключено'), findsNothing);
    expect(find.text('Подключаемся к голосовому каналу'), findsOneWidget);
    expect(find.text('Соединяемся с голосовой комнатой.'), findsNothing);
    final dockShareAction = find.descendant(
      of: find.byTooltip('Начать демонстрацию экрана').first,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(dockShareAction).onTap, isNull);

    state.deafenChanging = true;
    state.notifyListeners();
    await tester.pump();
    final deafenButton = find.descendant(
      of: find.byTooltip('Выключить удалённый звук'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(deafenButton).onTap, isNull);

    state.deafenChanging = false;
    state.voicePhase = VoicePhase.connected;
    state.deafened = true;
    state.microphoneMuted = true;
    state.notifyListeners();
    await tester.pump();
    final deafenedButton = tester.getSemantics(
      find.byTooltip('Включить удалённый звук'),
    );
    expect(deafenedButton.label, 'Включить удалённый звук');
    expect(deafenedButton.flagsCollection.isToggled, Tristate.isTrue);
    for (final tooltip in ['Включить микрофон', 'Включить удалённый звук']) {
      final controlMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(Material),
        ),
      );
      expect(controlMaterial.color, GcColors.dangerSolid);
      expect(
        (controlMaterial.shape! as RoundedRectangleBorder).side.color,
        GcColors.danger,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byTooltip(tooltip),
                matching: find.byType(Icon),
              ),
            )
            .color,
        GcColors.onDanger,
      );
    }
    expect(
      find.text(
        'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
      ),
      findsNothing,
    );

    state.voicePhase = VoicePhase.reconnecting;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Восстанавливаем голосовое соединение'), findsOneWidget);
    expect(find.text('Ручной выход отменит ожидание.'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('Восстанавливаем голосовое соединение'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
      ),
      findsNothing,
    );

    state.voicePhase = VoicePhase.leaving;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Завершаем голосовое подключение'), findsOneWidget);
    expect(find.text('Ожидаем завершения голосовой сессии.'), findsNothing);
    expect(find.byTooltip('Выходим…'), findsOneWidget);
    final leaveButton = find.descendant(
      of: find.byTooltip('Выходим…'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(leaveButton).onTap, isNull);
    final leaveButtonSemantics = tester.getSemantics(
      find.byTooltip('Выходим…'),
    );
    expect(leaveButtonSemantics.label, 'Выходим…');
    expect(
      leaveButtonSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );

    state.error = 'Голосовая сессия завершилась с ошибкой';
    state.notifyListeners();
    await tester.pump();
    expect(find.text(state.error!), findsOneWidget);
    final alert = find.ancestor(
      of: find.text(state.error!),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.alert,
      ),
    );
    expect(
      tester.getSemantics(alert).getSemanticsData().role,
      SemanticsRole.alert,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await tester.runAsync(() => room.dispose());
  });

  testWidgets('keeps voice controls in a compact bottom dock on Android', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.microphoneMuted = false;
    state.microphoneUnavailable = false;
    state.deafened = false;
    state.audioActivationMode = AudioActivationMode.vad;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('mobile-voice-dock'));
    expect(dock, findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Открыть навигацию')).left,
      lessThan(24),
    );
    expect(
      tester.getRect(find.text('Голос подключён')).left,
      greaterThan(tester.getRect(dock).left + 32),
    );
    expect(find.byTooltip('Выключить микрофон'), findsOneWidget);
    expect(find.byTooltip('Выключить удалённый звук'), findsOneWidget);
    expect(
      find.descendant(
        of: dock,
        matching: find.byTooltip('Начать демонстрацию экрана'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Выйти из голосового канала'), findsOneWidget);
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(844));

    expect(find.byTooltip('Развернуть голосовую панель'), findsNothing);
    expect(find.byTooltip('Свернуть голосовую панель'), findsNothing);
    expect(find.textContaining('Вы можете открыть другой канал'), findsNothing);
    final dockHeight = tester.getRect(dock).height;
    await tester.drag(dock, const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(tester.getRect(dock).height, dockHeight);
    expect(find.textContaining('Вы можете открыть другой канал'), findsNothing);
    expect(state.voiceChannel, isNotNull);

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    expect(dock, findsOneWidget);
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(844));

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'resets viewer state through app rebuild on voice channel change',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final state = AppState(
        _PortraitApi(extraVoiceChannels: [_PortraitApi.secondVoiceChannel]),
      );
      await state.initialize();
      state.selectedChannel = _PortraitApi.voiceChannel;
      state.voiceChannel = _PortraitApi.voiceChannel;
      state.voicePhase = VoicePhase.connected;
      await tester.pumpWidget(BoohtacordApp(state: state));
      await tester.pumpAndSettle();

      final firstRoom = tester.state(
        find.byKey(const ValueKey('voice-room:voice-1')),
      );
      await state.selectChannel(_PortraitApi.secondVoiceChannel);
      await tester.pumpAndSettle();

      final secondRoom = tester.state(
        find.byKey(const ValueKey('voice-room:voice-2')),
      );
      expect(identical(firstRoom, secondRoom), isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('shows channel administration only for administrators', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Роли и доступ к этой гильдии'), findsOneWidget);
    expect(find.text('@peer'), findsOneWidget);
    expect(find.text('Сбросить пароль'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
    await tester.pumpAndSettle();
    final channelPicker = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(channelPicker);
    await tester.tap(channelPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('общий').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-screen-title')), findsOneWidget);
    expect(find.text('Создать раздел'), findsOneWidget);
    expect(find.text('Создать канал'), findsOneWidget);
    expect(find.text('Раздел выше'), findsOneWidget);
    expect(find.text('Канал выше'), findsOneWidget);
    expect(find.text('Перенести канал'), findsNWidgets(2));
    expect(find.text('Текстовый канал для архивации'), findsOneWidget);
    expect(find.text('Голосовой канал для закрытия'), findsOneWidget);
    expect(find.text('Архивировать канал'), findsOneWidget);
    expect(find.text('Закрыть вход'), findsOneWidget);
    expect(find.byTooltip('Обновить список каналов'), findsOneWidget);

    final archivePicker = find.byKey(const ValueKey('archive-channel:null'));
    await tester.ensureVisible(archivePicker);
    await tester.tap(archivePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('общий').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать канал'));
    await tester.pumpAndSettle();
    expect(find.textContaining('История сообщений сохранится'), findsOneWidget);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();

    final closePicker = find.byKey(const ValueKey('close-channel:null'));
    await tester.ensureVisible(closePicker);
    await tester.tap(closePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('комната').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрыть вход'));
    await tester.pumpAndSettle();
    expect(find.textContaining('отзыв media-доступа в SFU'), findsOneWidget);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аудит'));
    await tester.pumpAndSettle();
    expect(
      find.text('События управления без содержимого сообщений'),
      findsOneWidget,
    );
    expect(find.text('Создан канал'), findsOneWidget);
    expect(find.text('Инициатор · Admin (@admin)'), findsOneWidget);
    expect(find.text('Показать более ранние'), findsOneWidget);
    await tester.tap(find.text('Показать более ранние'));
    await tester.pumpAndSettle();
    expect(find.text('Завершён сброс пароля'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    final memberState = AppState(_PortraitApi());
    await memberState.initialize();
    memberState.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(state: memberState)),
    );
    expect(find.text('Создать раздел'), findsNothing);
    expect(find.text('Создать канал'), findsNothing);
    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    memberState.dispose();
  });

  testWidgets('preserves member drafts on failure and handles reset links', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('role:account-2:MEMBER')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    api.failAdminUpdate = true;
    final saveButton = find.byKey(const ValueKey('save-account:account-2'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Запрос отклонён сервером.'), findsOneWidget);
    expect(api.adminUpdates, [('account-2', 'ADMINISTRATOR', true)]);
    expect(find.text('Администратор'), findsWidgets);
    expect(find.byType(Switch).first, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).focusNode?.hasFocus, isTrue);

    api.failAdminUpdate = false;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Изменения для @peer сохранены.'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).focusNode?.hasFocus, isTrue);

    final resetButton = find.byKey(const ValueKey('reset-account:account-2'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('Одноразовая ссылка для @peer'), findsOneWidget);
    expect(
      find.text('https://v.bootybay.ru/reset-password#token=one-time'),
      findsOneWidget,
    );
    expect(find.textContaining('Истекает:'), findsOneWidget);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Скопировать ссылку'));
    await tester.pumpAndSettle();
    expect(copiedText, 'https://v.bootybay.ru/reset-password#token=one-time');

    await tester.tap(find.byTooltip('Закрыть и удалить ссылку'));
    await tester.pumpAndSettle();
    expect(find.text('Одноразовая ссылка для @peer'), findsNothing);
    expect(
      find.text('https://v.bootybay.ru/reset-password#token=one-time'),
      findsNothing,
    );

    api.failResetLink = true;
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось создать ссылку.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders audit error, empty, and refreshed event states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi()..failAudit = true;
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('admin-section-tab-audit')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить журнал аудита.'), findsOneWidget);

    api.failAudit = false;
    api.emptyAudit = true;
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет.'), findsOneWidget);

    api.emptyAudit = false;
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Создан канал'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows loading while audit pages are being fetched', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    api.auditGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-audit')));
    await tester.pump();
    expect(find.text('Загружаем аудит…'), findsOneWidget);
    api.auditGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Создан канал'), findsOneWidget);

    api.auditGate = Completer<void>();
    await tester.tap(find.text('Показать более ранние'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.auditGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Завершён сброс пароля'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('loads additional admin member pages using the cursor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi()..paginateAdminAccounts = true;
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('@peer'), findsOneWidget);
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();
    expect(api.adminAccountCursors, [null, 'cursor-next']);
    expect(find.text('@peer-2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('announces when a voice connection is reconnecting', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.reconnecting;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));

    expect(find.text('Восстанавливаем голосовое соединение'), findsOneWidget);
    expect(find.text('комната'), findsWidgets);
    expect(find.textContaining('Участников в голосовом канале:'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('offers listener-only voice join before microphone access', (
    tester,
  ) async {
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Подключиться к голосу'), findsOneWidget);
    expect(find.text('Подключиться без микрофона'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('opens text history at latest and advances its read cursor', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 40);
    final state = AppState(api);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(api.advancedMessageIds, contains('message-39'));

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    final messageList = find.byKey(const ValueKey('text-channel-messages'));
    final header = find.byKey(const ValueKey('workspace-header'));
    final composer = find.byKey(const ValueKey('text-composer-wrap'));
    final headerRectBefore = tester.getRect(header);
    final composerRectBefore = tester.getRect(composer);
    expect(find.byTooltip('Закрыть навигацию'), findsNothing);
    final scrollController = tester.widget<ListView>(messageList).controller!;
    final initialOffset = scrollController.position.pixels;
    expect(initialOffset, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(messageList));
    for (var step = 0; step < 8; step++) {
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      scrollController.position.pixels,
      lessThan(initialOffset),
      reason: 'a downward touch drag should reveal older channel messages',
    );
    expect(tester.getRect(header), headerRectBefore);
    expect(tester.getRect(composer), composerRectBefore);
    expect(find.byTooltip('Закрыть навигацию'), findsNothing);
    expect(api.advancedMessageIds, ['message-39']);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  for (final direct in [false, true]) {
    for (final freshScroll in [false, true]) {
      testWidgets(
        'late desktop checkpoint ${freshScroll ? 'keeps fresh user scroll' : 'restores history after initial layout'} (${direct ? 'DM' : 'channel'})',
        (tester) async {
          final state = AppState(
            _PortraitApi(
              withHistory: true,
              historyCount: 70,
              includeDirectMessage: direct,
              paginatedDirectHistory: direct,
              directHistoryCount: 70,
            ),
          );
          await state.initialize();
          if (direct) {
            await state.openDirectConversation(state.directMessages.single);
          }
          Widget workspace() => MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          );
          await tester.pumpWidget(workspace());
          await tester.pumpAndSettle();
          final list = find.byKey(
            ValueKey(
              direct ? 'direct-message-messages' : 'text-channel-messages',
            ),
          );
          var scroll = tester.widget<ListView>(list).controller!;
          scroll.jumpTo(scroll.position.maxScrollExtent / 2);
          await tester.pumpAndSettle();
          final account = state.user!.accountId;
          final conversation = direct
              ? 'dm:${state.selectedDirectMessage!.id}'
              : state.selectedChannel!.id;
          final snapshot = ConversationScrollMemory.exportForAccount(account);
          final position = snapshot.singleWhere(
            (e) => e['channel'] == conversation,
          );
          final anchorId = position['anchor'] as String;
          final anchorText = direct
              ? state.directMessageHistory
                    .singleWhere((m) => m.id == anchorId)
                    .body
              : state.messages.singleWhere((m) => m.id == anchorId).body;
          final beforeTop = tester.getTopLeft(find.text(anchorText)).dy;
          await tester.pumpWidget(const SizedBox.shrink());
          ConversationScrollMemory.clear();
          // The disk/network restore can finish after the initial layout.
          // Its automatic movement is not a fresh user scroll choice.
          final beforeRead = ConversationScrollMemory.revision;
          await tester.pumpWidget(workspace());
          await tester.pumpAndSettle();
          scroll = tester.widget<ListView>(list).controller!;
          if (freshScroll) {
            // A real input gesture during the delayed read must win, including
            // after the gesture ends and userScrollDirection returns to idle.
            final offsetBeforeGesture = scroll.position.pixels;
            await tester.drag(
              list,
              Offset(0, offsetBeforeGesture < 160 ? -160 : 160),
            );
            await tester.pumpAndSettle();
            expect(scroll.position.pixels, isNot(offsetBeforeGesture));
          }
          final freshOffset = scroll.position.pixels;
          ConversationScrollMemory.importForAccount(
            account,
            snapshot,
            unchangedSince: beforeRead,
          );
          expect(
            ConversationScrollMemory.load(
              account,
              conversation,
            )?.restoredFromDisk,
            !freshScroll,
          );
          state.notifyListeners();
          await tester.pumpAndSettle();
          if (freshScroll) {
            expect(scroll.position.pixels, closeTo(freshOffset, 1));
          } else {
            expect(find.text(anchorText), findsOneWidget);
            expect(
              tester.getTopLeft(find.text(anchorText)).dy,
              closeTo(beforeTop, 1),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }

  testWidgets('preserves the visible text anchor when loading an older page', (
    tester,
  ) async {
    final api = _PortraitApi(
      withHistory: true,
      historyCount: 30,
      paginatedHistory: true,
    );
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.nextMessageCursor, 'older-page');
    expect(api.advancedMessageIds.last, 'message-29');
    final list = find.byKey(const ValueKey('text-channel-messages'));
    final scroll = tester.widget<ListView>(list).controller!;
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    final anchor = find.text('Сообщение 0');
    expect(anchor, findsOneWidget);
    final anchorTopBefore = tester.getTopLeft(anchor).dy;

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(api.messagePageCalls, 2);
    expect(state.messages.first.id, 'older-message-0');
    expect(
      tester.getTopLeft(anchor).dy,
      closeTo(anchorTopBefore, 1),
      reason: 'loading a page above the viewport must not move its visible row',
    );
    expect(api.advancedMessageIds, isNot(contains('older-message-0')));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('preserves the visible DM anchor when loading an older page', (
    tester,
  ) async {
    final api = _PortraitApi(
      includeDirectMessage: true,
      paginatedDirectHistory: true,
      directHistoryCount: 30,
    );
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.nextDirectMessageCursor, 'older-dm-page');
    expect(api.advancedDirectMessageIds.last, 'dm-message-29');
    final anchor = find.text('Личное сообщение 0');
    expect(anchor, findsOneWidget);
    final anchorTopBefore = tester.getTopLeft(anchor).dy;

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(api.directMessagePageCalls, 2);
    expect(state.directMessageHistory.first.id, 'older-dm-message-0');
    expect(
      tester.getTopLeft(anchor).dy,
      closeTo(anchorTopBefore, 1),
      reason:
          'loading a DM page above the viewport must not move its visible row',
    );
    expect(api.advancedDirectMessageIds, ['dm-message-29']);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps older text-page failures inline and retryable', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, paginatedHistory: true)
      ..failOlderTextPages = 1;
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(state.error, isNull);
    expect(state.nextMessageCursor, 'older-page');
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Сеть недоступна'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(api.messagePageCalls, 3);
    expect(state.messages.first.id, 'older-message-0');
    expect(find.text('Повторить'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps older DM-page failures inline and retryable', (
    tester,
  ) async {
    final api = _PortraitApi(
      includeDirectMessage: true,
      paginatedDirectHistory: true,
      directHistoryCount: 2,
    )..failOlderDirectPages = 1;
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(state.error, isNull);
    expect(state.nextDirectMessageCursor, 'older-dm-page');
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Сеть недоступна'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(api.directMessagePageCalls, 3);
    expect(state.directMessageHistory.first.id, 'older-dm-message-0');
    expect(find.text('Повторить'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('selects a reply target and sends a reply in a text channel', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2);
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();

    expect(find.text('Ответ для @Участник'), findsOneWidget);
    await tester.tap(find.byTooltip('Выбрать упоминание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ответ из клиента');
    await tester.tap(find.byTooltip('Отправить сообщение'));
    await tester.pumpAndSettle();

    expect(api.sentReplyToId, 'message-1');
    expect(api.sentMentionIds, ['account-2']);
    expect(state.messages.last.body, 'Ответ из клиента');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('reply composer geometry matches Design V2 for text and DM', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(
        withHistory: true,
        historyCount: 2,
        includeDirectMessage: true,
      ),
    );
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> selectReplyTarget() async {
      await tester.tap(find.byTooltip('Действия с сообщением').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();
    }

    void expectReplyGeometry({required double fieldHeight}) {
      final wrapper = tester.widget<Container>(
        find.byKey(const ValueKey('text-composer-wrap')),
      );
      expect(wrapper.padding, const EdgeInsets.fromLTRB(24, 0, 24, 18));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('reply-target-banner')))
            .height,
        41,
      );
      final banner = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('reply-target-banner')),
          matching: find.byType(Container),
        ),
      );
      expect(
        (banner.decoration! as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(10)),
      );
      expect((banner.decoration! as BoxDecoration).color, GcColors.surface);
      expect(tester.getRect(find.byType(TextField).last).height, fieldHeight);
      expect(
        tester.getRect(find.byKey(const ValueKey('text-composer-wrap'))).height,
        131,
      );
      expect(find.text('Отмена'), findsOneWidget);
      final decoration = tester
          .widget<TextField>(find.byType(TextField).last)
          .decoration!;
      expect(decoration.hintText, 'Написать сообщение…');
      expect(decoration.fillColor, GcColors.raised);
      expect(
        (decoration.enabledBorder as OutlineInputBorder).borderRadius,
        const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );
    }

    void expectDirectReplyGeometry({required double fieldHeight}) {
      final wrapper = tester.widget<Container>(
        find.byKey(const ValueKey('direct-message-composer-wrap')),
      );
      expect(wrapper.padding, const EdgeInsets.fromLTRB(24, 0, 24, 18));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
            .height,
        131,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('reply-target-banner')))
            .height,
        41,
      );
      final decoration = tester
          .widget<TextField>(find.byType(TextField).last)
          .decoration!;
      expect(decoration.hintText, 'Написать сообщение…');
      expect(decoration.fillColor, GcColors.raised);
      expect(tester.getRect(find.byType(TextField).last).height, fieldHeight);
      expect(
        (decoration.enabledBorder as OutlineInputBorder).borderRadius,
        const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );
    }

    await selectReplyTarget();
    expectReplyGeometry(fieldHeight: 54);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expectReplyGeometry(fieldHeight: 52);

    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpAndSettle();
    await selectReplyTarget();
    expectDirectReplyGeometry(fieldHeight: 52);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expectDirectReplyGeometry(fieldHeight: 54);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reply-target-banner')), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      70,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'opens a reply context when its target is outside loaded history',
    (tester) async {
      final api = _PortraitApi(withHistory: true)
        ..replyContextPage = ChatMessagePage(
          messages: [
            ChatMessage(
              id: 'older-reply-target',
              channelId: _PortraitApi.channel.id,
              authorId: 'account-2',
              body: 'Исходное сообщение из старой страницы',
              createdAt: DateTime.utc(2026, 9, 24),
              deleted: false,
              revision: 1,
            ),
          ],
        );
      final state = AppState(api);
      await state.initialize();
      state.messages = [
        ChatMessage(
          id: 'reply-message',
          channelId: _PortraitApi.channel.id,
          authorId: 'account-1',
          body: 'Ответ в текущей странице',
          createdAt: DateTime.utc(2026, 9, 25),
          deleted: false,
          revision: 1,
          replyToId: 'older-reply-target',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Исходное сообщение недоступно'));
      await tester.pumpAndSettle();

      expect(api.lastMessageAt, 'older-reply-target');
      expect(state.workspacePanel, WorkspacePanel.searchContext);
      expect(find.text('Контекст ответа'), findsOneWidget);
      expect(
        find.text('Исходное сообщение из старой страницы'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('message composer groups attachment and paste actions', (
    tester,
  ) async {
    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Вложение и вставка'));
    await tester.pumpAndSettle();

    expect(find.text('Прикрепить файл'), findsOneWidget);
    expect(find.text('Вставить из буфера'), findsOneWidget);
    expect(find.byTooltip('Выбрать упоминание'), findsOneWidget);
    expect(find.byTooltip('Добавить emoji'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить 😀'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '😀',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'compact composer groups attachment, paste, and mention actions under plus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final state = AppState(_PortraitApi());
      await state.initialize();
      await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial compact layout');

      expect(find.byTooltip('Действия редактора'), findsOneWidget);
      expect(find.byTooltip('Выбрать упоминание'), findsNothing);

      await tester.tap(find.byTooltip('Действия редактора'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'compact action menu');
      expect(find.text('Прикрепить файл'), findsOneWidget);
      expect(find.text('Вставить из буфера'), findsOneWidget);
      expect(find.text('Упомянуть'), findsOneWidget);
      expect(find.text('Emoji'), findsOneWidget);

      await tester.tap(find.text('Упомянуть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'mention picker');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Собеседник'), findsOneWidget);

      await tester.tap(find.text('Собеседник'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.text('@Собеседник'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('compact DM composer opens mention picker from plus menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi(includeDirectMessage: true));
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Действия редактора'), findsOneWidget);
    expect(find.byTooltip('Выбрать упоминание'), findsNothing);
    await tester.tap(find.byTooltip('Действия редактора'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Упомянуть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(find.text('@Собеседник'), findsOneWidget);
    await tester.tap(find.byTooltip('Действия редактора'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить 🎮'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '🎮',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('compact TEXT composer searches and inserts emoji at selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(find.byType(TextField).last);
    composer.controller!.value = const TextEditingValue(
      text: 'Привет мир',
      selection: TextSelection(baseOffset: 10, extentOffset: 7),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Действия редактора'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emoji'));
    await tester.pumpAndSettle();
    expect(find.text('Выбор emoji'), findsOneWidget);

    await tester.tap(find.text('Все emoji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byTooltip('Поиск emoji'), findsOneWidget);
    await tester.enterText(find.byTooltip('Поиск emoji'), 'палец');
    await tester.pump();
    final searchField = find.descendant(
      of: find.byTooltip('Поиск emoji'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(searchField).controller!.text, 'палец');
    expect(find.text('👍🏽'), findsOneWidget);
    await tester.tap(find.text('👍🏽'));
    await tester.pumpAndSettle();

    expect(composer.controller!.text, 'Привет 👍🏽');
    expect(
      composer.controller!.selection,
      const TextSelection.collapsed(offset: 11),
    );
    final emojiPreferences = await SharedPreferences.getInstance();
    expect(
      emojiPreferences.getStringList('boohtacord-recent-emoji')?.first,
      '👍🏽',
    );

    await tester.tap(find.byTooltip('Действия редактора'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все emoji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Недавние'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'opens a DM reply context when its target is outside loaded history',
    (tester) async {
      final api = _PortraitApi(includeDirectMessage: true)
        ..directReplyContextPage = DirectChatMessagePage(
          messages: [
            DirectChatMessage(
              id: 'older-dm-reply-target',
              directMessageId: 'dm-1',
              authorId: 'account-2',
              body: 'Старое личное сообщение',
              createdAt: DateTime.utc(2026, 9, 24),
              deleted: false,
              revision: 1,
            ),
          ],
        );
      final state = AppState(api);
      await state.initialize();
      await state.openDirectConversation(state.directMessages.single);
      state.directMessageHistory = [
        DirectChatMessage(
          id: 'dm-reply-message',
          directMessageId: 'dm-1',
          authorId: 'account-1',
          body: 'Ответ в личной переписке',
          createdAt: DateTime.utc(2026, 9, 25),
          deleted: false,
          revision: 1,
          replyToId: 'older-dm-reply-target',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Исходное сообщение недоступно'));
      await tester.pumpAndSettle();

      expect(api.lastDirectMessageAt, 'older-dm-reply-target');
      expect(state.workspacePanel, WorkspacePanel.searchContext);
      expect(find.text('Контекст ответа'), findsOneWidget);
      expect(find.text('Старое личное сообщение'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('text composer submits from the soft-keyboard send action', (
    tester,
  ) async {
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    expect(
      tester.widget<TextField>(composer).textInputAction,
      TextInputAction.send,
    );
    await tester.enterText(composer, 'Отправка с клавиатуры');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(api.textSendIds, hasLength(1));
    expect(state.messages.last.body, 'Отправка с клавиатуры');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('text composer does not send on Shift+Enter', (tester) async {
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    await tester.tap(composer);
    await tester.enterText(composer, 'Первая строка');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(api.textSendIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('direct-message composer submits from the soft-keyboard action', (
    tester,
  ) async {
    final api = _PortraitApi(includeDirectMessage: true);
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    expect(
      tester.widget<TextField>(composer).textInputAction,
      TextInputAction.send,
    );
    await tester.enterText(composer, 'Личное сообщение с клавиатуры');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      state.directMessageHistory.last.body,
      'Личное сообщение с клавиатуры',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows a failed text send and retries the same client ID', (
    tester,
  ) async {
    final api = _PortraitApi()..failTextSends = 1;
    final state = AppState(api);
    await state.initialize();
    expect(await state.send('Повторяемое сообщение'), isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Повторить отправку'), findsOneWidget);
    expect(state.messages.last.sendStatus, MessageSendStatus.failed);
    await tester.tap(find.text('Повторить отправку'));
    await tester.pumpAndSettle();

    expect(api.textSendIds, hasLength(2));
    expect(api.textSendIds.last, api.textSendIds.first);
    expect(state.messages.last.sendStatus, isNull);
    expect(find.text('Повторить отправку'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps an edit draft through revision conflict and refresh', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2)
      ..textEditConflicts = 1;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Мой сохранённый черновик',
    );
    await tester.tap(find.byTooltip('Выбрать упоминание').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Обновите версию'),
      ),
      findsOneWidget,
    );
    expect(find.text('Мой сохранённый черновик'), findsOneWidget);
    expect(find.text('Обновить версию'), findsOneWidget);
    expect(state.messages, hasLength(2));

    await tester.tap(find.text('Обновить версию'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Версия обновлена'), findsOneWidget);
    expect(find.text('Мой сохранённый черновик'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(api.textEditRevisions, [1, 2]);
    expect(api.textEditMentionIds, [
      ['account-2'],
      ['account-2'],
    ]);
    expect(state.messages.last.body, 'Мой сохранённый черновик');
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps a deleted-during-edit draft available for copying', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 1)
      ..textEditConflicts = 1
      ..deleteTextOnConflict = true;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Черновик для копирования',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обновить версию'));
    await tester.pumpAndSettle();

    expect(state.messages.single.deleted, isTrue);
    expect(find.text('Черновик для копирования'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('черновик сохранён для копирования'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('selects a reply target and sends a direct-message reply', (
    tester,
  ) async {
    final api = _PortraitApi(includeDirectMessage: true);
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();

    expect(find.text('Ответ для Собеседник'), findsOneWidget);
    await tester.tap(find.byTooltip('Выбрать упоминание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ответ в личке');
    await tester.tap(find.byTooltip('Отправить личное сообщение'));
    await tester.pumpAndSettle();

    expect(api.sentDirectReplyToId, 'dm-message-1');
    expect(api.sentDirectMentionIds, ['account-2']);
    expect(state.directMessageHistory.last.body, 'Ответ в личке');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search opens a hit in context and returns to the origin', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2);
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();
    expect(find.text('Найдите нужное сообщение'), findsOneWidget);
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    expect(searchField, findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-search-submit')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(api.lastSearchQuery, isNull);
    expect(find.text('Введите поисковый запрос.'), findsNothing);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'current',
    );
    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Поиск сообщений',
      ),
      'найденный текст',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.lastSearchQuery, 'найденный текст');
    expect(find.text('Найдено 1 сообщения'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Открыть сообщение от Участник',
      ),
      findsOneWidget,
    );
    final resultCard = find.byKey(const ValueKey('search-result-message-1'));
    final resultHeader = find.descendant(
      of: resultCard,
      matching: find.textContaining('#общий · 25 сентября'),
    );
    final resultAvatar = find.descendant(
      of: resultCard,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Аватар Участник',
      ),
    );
    expect(resultHeader, findsOneWidget);
    expect(resultAvatar, findsOneWidget);
    expect(
      tester.getTopLeft(resultHeader).dy,
      lessThan(tester.getTopLeft(resultAvatar).dy),
    );
    expect(resultCard, findsOneWidget);
    final resultStatus = find.byKey(const ValueKey('search-live-status'));
    expect(resultStatus, findsOneWidget);
    expect(
      tester.getSemantics(resultStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    api.searchGate = Completer<SearchMessagePage>();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Поиск сообщений',
      ),
      'следующий запрос',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    final loadingStatus = find.byKey(const ValueKey('search-live-status'));
    expect(loadingStatus, findsOneWidget);
    expect(find.text('Ищем сообщения…'), findsOneWidget);
    expect(
      tester.getSemantics(loadingStatus).flagsCollection.isLiveRegion,
      isTrue,
    );
    api.searchGate!.complete(
      SearchMessagePage(
        messages: [
          SearchMessage(
            id: 'message-1',
            kind: SearchMessageKind.channel,
            conversationId: _PortraitApi.channel.id,
            authorId: 'account-1',
            body: 'Найденный текст',
            createdAt: DateTime.utc(2026, 9, 25),
            revision: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Найдено 1 сообщения'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-result-message-1')));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.searchContext);
    expect(find.text('Контекст найденного сообщения'), findsOneWidget);
    expect(find.text('Последнее сообщение'), findsOneWidget);

    await tester.tap(find.text('Вернуться к беседе'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(state.selectedChannel?.id, _PortraitApi.channel.id);
    expect(find.text('Последнее сообщение'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search announces an empty result state as a live region', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true)..emptySearchResults = true;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Поиск сообщений',
      ),
      'нет совпадений',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final emptyStatus = find.byKey(const ValueKey('search-live-status'));
    expect(emptyStatus, findsOneWidget);
    expect(
      tester.getSemantics(emptyStatus).flagsCollection.isLiveRegion,
      isTrue,
    );
    expect(find.text('Совпадений нет.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Ctrl+K opens search but does not steal text input focus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.search);
    expect(find.text('Последнее сообщение'), findsOneWidget);
    final searchScope =
        tester
                .widgetList<FocusScope>(find.byType(FocusScope))
                .firstWhere((scope) => scope.debugLabel == 'workspace-search')
                .focusNode!
            as FocusScopeNode;
    expect(searchScope.hasFocus, isTrue);
    expect(searchScope.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Поиск сообщений',
            ),
          )
          .focusNode!
          .hasPrimaryFocus,
      isTrue,
    );

    final composer = find.byType(TextField).first;
    await tester.tap(composer);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('wide search keeps the active conversation beside the panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      find.byKey(const ValueKey('workspace-search-scope')),
      findsOneWidget,
    );
    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 380,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Закрыть панель'), findsNothing);
    expect(
      tester
          .widgetList<FocusScope>(find.byType(FocusScope))
          .where((scope) => scope.debugLabel == 'workspace-search'),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('medium desktop search uses the 380 px web panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 380,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('compact search uses the full viewport web overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true));
    await state.initialize();
    state.openSearchPanel();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = find.byKey(const ValueKey('workspace-search-overlay'));
    expect(tester.getSize(overlay), const Size(390, 844));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('workspace-search-header')))
          .height,
      68,
    );
    final close = find.byTooltip('Закрыть поиск');
    expect(tester.getSize(close), const Size(44, 44));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('workspace-search-query')))
          .height,
      44,
    );
    expect(
      find.byKey(const ValueKey('workspace-search-enter-hint')),
      findsNothing,
    );
    expect(find.text('Найти'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-search-query-icon')),
      findsOneWidget,
    );
    expect(find.text('Поиск сообщений'), findsWidgets);
    expect(
      find.byKey(const ValueKey('workspace-search-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'compact search panel has a readable scope and designed empty state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(407, 318);
      addTearDown(tester.view.reset);
      final state = AppState(_PortraitApi(withHistory: true));
      await state.initialize();
      await state.selectChannel(_PortraitApi.channel);
      state.openSearchPanel();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scope = find.byKey(const ValueKey('workspace-search-scope'));
      expect(tester.getSize(scope).width, greaterThan(120));
      expect(tester.getSize(scope).height, 32);
      expect(
        find.byKey(const ValueKey('workspace-search-query-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace-search-empty-state')),
        findsOneWidget,
      );
      expect(find.text('Найдите нужное сообщение'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workspace-search-submit')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('wide voice search keeps its 320 px modal drawer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'all',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.width == 320,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 380,
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search defaults to the active direct-message conversation', (
    tester,
  ) async {
    final state = AppState(_PortraitApi(includeDirectMessage: true));
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'current',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search query and scope are restored per conversation', (
    tester,
  ) async {
    final api = _PortraitApi(includeDirectMessage: true)
      ..searchResultPage = SearchMessagePage(
        messages: List.generate(
          20,
          (index) => SearchMessage(
            id: 'search-result-$index',
            kind: SearchMessageKind.channel,
            conversationId: _PortraitApi.channel.id,
            authorId: 'account-1',
            body: 'Результат поиска $index',
            createdAt: DateTime.utc(2026, 9, 25).add(Duration(minutes: index)),
            revision: 1,
          ),
        ),
      );
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> search(String query) async {
      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Поиск сообщений',
      );
      await tester.enterText(searchField, query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    double resultsScrollOffset() {
      final listView = tester.widget<ListView>(
        find.descendant(
          of: find.byKey(const ValueKey('workspace-search-panel')),
          matching: find.byType(ListView),
        ),
      );
      return listView.controller!.offset;
    }

    state.openSearchPanel();
    await tester.pumpAndSettle();
    await search('поиск в личном диалоге');
    expect(api.searchRequests.last, ('поиск в личном диалоге', null, 'dm-1'));
    final resultsList = find.descendant(
      of: find.byKey(const ValueKey('workspace-search-panel')),
      matching: find.byType(ListView),
    );
    await tester.drag(resultsList, const Offset(0, -300));
    await tester.pumpAndSettle();
    final dmResultsOffset = resultsScrollOffset();
    expect(dmResultsOffset, greaterThan(0));

    state.closeSearchPanel();
    await tester.pumpAndSettle();
    expect(
      state.workspace.searchSessions['dm:dm-1']?.scrollOffset,
      closeTo(dmResultsOffset, 1),
    );
    await state.selectChannel(_PortraitApi.channel);
    await tester.pumpAndSettle();
    state.openSearchPanel();
    await tester.pumpAndSettle();
    final channelSearchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    expect(
      tester.widget<TextField>(channelSearchField).controller!.text,
      isEmpty,
    );
    await search('поиск в текстовом канале');
    expect(api.searchRequests.last, (
      'поиск в текстовом канале',
      _PortraitApi.channel.id,
      null,
    ));

    state.closeSearchPanel();
    await tester.pumpAndSettle();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpAndSettle();
    api.searchGate = Completer<SearchMessagePage>();
    state.openSearchPanel();
    await tester.pump();
    expect(find.text('Ищем сообщения…'), findsOneWidget);
    expect(find.text('Найдите нужное сообщение'), findsNothing);
    api.searchGate!.complete(api.searchResultPage!);
    await tester.pumpAndSettle();
    api.searchGate = null;
    final restoredDmSearchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    expect(
      tester.widget<TextField>(restoredDmSearchField).controller!.text,
      'поиск в личном диалоге',
    );
    expect(api.searchRequests.last, ('поиск в личном диалоге', null, 'dm-1'));
    expect(resultsScrollOffset(), closeTo(dmResultsOffset, 1));

    state.closeSearchPanel();
    await tester.pumpAndSettle();
    await state.selectChannel(_PortraitApi.channel);
    await tester.pumpAndSettle();
    state.openSearchPanel();
    await tester.pumpAndSettle();
    final restoredChannelSearchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    expect(
      tester.widget<TextField>(restoredChannelSearchField).controller!.text,
      'поиск в текстовом канале',
    );
    expect(api.searchRequests.last, (
      'поиск в текстовом канале',
      _PortraitApi.channel.id,
      null,
    ));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('active DM search survives desktop and mobile resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    final api = _PortraitApi(includeDirectMessage: true);
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    state.openSearchPanel();
    await tester.pumpAndSettle();
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    await tester.enterText(searchField, 'поиск после изменения ширины');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.searchRequests.last, (
      'поиск после изменения ширины',
      null,
      'dm-1',
    ));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.search);
    final mobileSearchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Поиск сообщений',
    );
    expect(
      tester.widget<TextField>(mobileSearchField).controller!.text,
      'поиск после изменения ширины',
    );
    expect(api.searchRequests.last, (
      'поиск после изменения ширины',
      null,
      'dm-1',
    ));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  for (final profile in [
    (name: 'mobile', size: Size(390, 844)),
    (name: 'desktop', size: Size(1440, 900)),
  ]) {
    testWidgets(
      'DM search result returns to its conversation and draft (${profile.name})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = profile.size;
        addTearDown(tester.view.reset);

        final api = _PortraitApi(includeDirectMessage: true)
          ..searchResultPage = SearchMessagePage(
            messages: [
              SearchMessage(
                id: 'dm-message-1',
                kind: SearchMessageKind.directMessage,
                conversationId: 'dm-1',
                authorId: 'account-2',
                body: 'Найденное личное сообщение',
                createdAt: DateTime.utc(2026, 9, 25),
                revision: 1,
              ),
            ],
          );
        final state = AppState(api);
        await state.initialize();
        await state.openDirectConversation(state.directMessages.single);
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'Черновик личного сообщения',
        );
        await tester.pump();
        state.openSearchPanel();
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == 'Поиск сообщений',
          ),
          'найденное личное сообщение',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(api.lastSearchQuery, 'найденное личное сообщение');
        expect(api.lastSearchDirectMessageId, 'dm-1');
        await tester.tap(
          find.byKey(const ValueKey('search-result-dm-message-1')),
        );
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.searchContext);
        expect(state.selectedDirectMessage?.id, 'dm-1');
        expect(api.lastDirectMessageAt, 'dm-message-1');
        expect(find.text('Исходное личное сообщение'), findsOneWidget);

        final compactBack = find.byTooltip('Вернуться к беседе');
        await tester.tap(
          compactBack.evaluate().isNotEmpty
              ? compactBack
              : find.text('Вернуться к беседе'),
        );
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.none);
        expect(state.selectedDirectMessage?.id, 'dm-1');
        expect(find.text('Исходное личное сообщение'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          'Черновик личного сообщения',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      },
    );
  }

  testWidgets('portrait layout keeps the channel open behind drawers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));

    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(find.byTooltip('Открыть навигацию'), findsOneWidget);

    await tester.tap(find.byTooltip('Открыть навигацию'));
    final returnFocus = FocusManager.instance.primaryFocus;
    await tester.pumpAndSettle();

    final drawerScope = tester
        .widgetList<FocusScope>(find.byType(FocusScope))
        .firstWhere((scope) => scope.debugLabel == 'workspace-drawer');
    final drawerFocusScope = drawerScope.focusNode! as FocusScopeNode;
    expect(drawerFocusScope.hasFocus, isTrue);
    expect(
      drawerFocusScope.traversalEdgeBehavior,
      TraversalEdgeBehavior.closedLoop,
    );
    final drawerFocusables = drawerFocusScope.traversalDescendants
        .where((node) => node.context != null)
        .toList();
    expect(drawerFocusables, isNotEmpty);
    drawerFocusables.last.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(drawerFocusScope.hasFocus, isTrue);
    expect(drawerFocusables, contains(FocusManager.instance.primaryFocus));

    expect(find.text('Каналы'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('@2'), findsOneWidget);
    expect(find.text('9'), findsNothing);
    expect(find.text('@3'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Закрыть навигацию'));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(returnFocus));
    await tester.tap(find.byTooltip('Открыть участников'));
    await tester.pumpAndSettle();
    expect(find.text('УЧАСТНИКИ'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть участников'));
    await tester.pumpAndSettle();
    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('groups guild members by presence with web-equivalent counts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    const members = [
      GuildMember(
        id: '11111111-1111-4111-8111-111111111111',
        login: 'online',
        displayName: 'В сети',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
      GuildMember(
        id: '22222222-2222-4222-8222-222222222222',
        login: 'offline',
        displayName: 'Не в сети',
        role: 'MEMBER',
        presence: MemberPresence.offline,
      ),
      GuildMember(
        id: '33333333-3333-4333-8333-333333333333',
        login: 'unknown',
        displayName: 'Неизвестен',
        role: 'MEMBER',
        presence: MemberPresence.unknown,
      ),
    ];
    final api = _PortraitApi(
      membersResult: members,
      membersFailures: 1,
      memberProfileFailures: 1,
    );
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final membersPanel = find.byKey(const ValueKey('members-panel'));
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Список участников временно недоступен.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Повторить')),
      findsOneWidget,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(api.membersFailures, 0);
    expect(state.membersError, isNull);
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Список участников временно недоступен.'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Не в сети — 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Статус неизвестен — 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Неизвестен')),
      findsOneWidget,
    );

    state.guildPresence.invalidate();
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Статус неизвестен — 3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsNothing,
    );

    state.guildPresence.acceptSnapshot([
      '11111111-1111-4111-8111-111111111111',
    ]);
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsOneWidget,
    );
    await tester.tap(find.text('Неизвестен'));
    await tester.pumpAndSettle();
    final profilePopover = find.byKey(const ValueKey('member-profile-popover'));
    expect(
      find.text('Не удалось загрузить профиль участника.'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: profilePopover, matching: find.text('Повторить')),
    );
    await tester.pumpAndSettle();
    expect(profilePopover, findsOneWidget);
    expect(find.text('@unknown'), findsOneWidget);
    final memberRow = find.ancestor(
      of: find.text('Неизвестен'),
      matching: find.byType(ListTile),
    );
    final rowRect = tester.getRect(memberRow);
    final popoverRect = tester.getRect(profilePopover);
    expect(popoverRect.width, 288);
    expect(popoverRect.left, greaterThanOrEqualTo(8));
    expect(popoverRect.right, lessThanOrEqualTo(rowRect.left));
    expect(popoverRect.top, closeTo(rowRect.top, 1));
    expect(
      popoverRect.bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height - 8),
    );
    final profileAvatar = tester.widget<AuthenticatedAvatar>(
      find.descendant(
        of: profilePopover,
        matching: find.byType(AuthenticatedAvatar),
      ),
    );
    expect(profileAvatar.radius, 32);
    expect(profileAvatar.backgroundColor, GcColors.avatarViolet);
    expect(profileAvatar.fallbackFontSize, 20);
    final profileName = tester.widget<Text>(
      find.descendant(of: profilePopover, matching: find.text('Неизвестен')),
    );
    expect(profileName.style?.fontSize, 20);
    final messageButton = find.descendant(
      of: profilePopover,
      matching: find.widgetWithText(OutlinedButton, 'Сообщение'),
    );
    expect(messageButton, findsOneWidget);
    expect(tester.getSize(messageButton).width, popoverRect.width - 32);
    expect(tester.getSize(messageButton).width, 256);
    expect(tester.getSize(messageButton).height, 40);
    expect(
      popoverRect.right,
      lessThanOrEqualTo(tester.view.physicalSize.width),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(profilePopover, findsNothing);
    final profileTrigger = tester.widget<Focus>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Focus &&
            widget.focusNode?.debugLabel == 'member-profile-trigger' &&
            widget.focusNode!.hasFocus,
      ),
    );
    expect(profileTrigger.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  for (final profile in [
    (
      name: 'mobile',
      size: const Size(393, 852),
      pixelRatio: 3.0,
      textScale: 1.0,
    ),
    (
      name: 'mobile-large-text',
      size: const Size(393, 852),
      pixelRatio: 3.0,
      textScale: 2.0,
    ),
    (
      name: 'desktop',
      size: const Size(1440, 900),
      pixelRatio: 2.0,
      textScale: 1.0,
    ),
  ]) {
    testWidgets('captures production Flutter text workspace at ${profile.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = profile.pixelRatio;
      tester.view.physicalSize = Size(
        profile.size.width * profile.pixelRatio,
        profile.size.height * profile.pixelRatio,
      );
      addTearDown(tester.view.reset);
      await loadUiuxVisualCaptureFonts();

      final state = AppState(
        _PortraitApi(
          withHistory: true,
          historyCount: 3,
          includeDirectMessage: true,
        ),
      );
      await state.initialize();
      state.selectedChannel = _PortraitApi.channel;
      final captureKey = ValueKey('uiux-workspace-capture-${profile.name}');
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(profile.textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: captureKey,
            child: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Последнее сообщение'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName:
            'flutter-text-channel-${profile.name}-${profile.size.width.toInt()}x${profile.size.height.toInt()}.png',
        pixelRatio: profile.pixelRatio,
      );

      await state.openDirectConversation(state.directMessages.single);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('direct-message-composer-wrap')),
        findsOneWidget,
      );
      expect(find.text('Исходное личное сообщение'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName:
            'flutter-dm-conversation-${profile.name}-${profile.size.width.toInt()}x${profile.size.height.toInt()}.png',
        pixelRatio: profile.pixelRatio,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Web parity matrix $width scale $scale short viewport and keyboard',
        (tester) async {
          // This presentation capture never starts a microphone check. The
          // recorder still creates/disposes a platform handle at widget mount.
          const recorder = MethodChannel('com.llfbandit.record/messages');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            recorder,
            (call) async {
              if (call.method == 'create' ||
                  call.method == 'dispose' ||
                  call.method == 'stop')
                return null;
              if (call.method == 'isRecording' || call.method == 'isPaused')
                return false;
              throw UnsupportedError(
                'Unexpected recorder call in presentation matrix',
              );
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(recorder, null),
          );

          const rtcEvents = MethodChannel('FlutterWebRTC.Event');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            rtcEvents,
            (_) async => null,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(rtcEvents, null),
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 480);
          addTearDown(tester.view.reset);
          await loadUiuxVisualCaptureFonts();
          final api = _PortraitApi(
            withHistory: true,
            historyCount: 3,
            includeDirectMessage: true,
          );
          final state = AppState(api, audioDeviceLoader: () async => const []);
          await state.initialize();
          state.selectedChannel = _PortraitApi.channel;
          final root = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: guildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: root,
                child: AnimatedBuilder(
                  animation: state,
                  builder: (_, _) => WorkspaceScreen(state: state),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> capture(String surface) async {
            expect(
              tester.takeException(),
              isNull,
              reason: '$surface $width x$scale',
            );
            await captureUiuxBoundary(
              tester,
              find.byKey(root),
              fileName:
                  'parity-$surface-${width.toInt()}x480-scale${scale.toInt()}.png',
              pixelRatio: 1,
            );
          }

          await capture('text');
          await tester.tap(find.byTooltip('Действия диалога'));
          await tester.pumpAndSettle();
          expect(find.text('Закреплённые'), findsOneWidget);
          await tester.tap(find.text('Поиск в диалоге'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('workspace-search-submit')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>),
                )
                .initialValue,
            'current',
          );
          await capture('search');
          if (width >= 1024) {
            final query = find.descendant(
              of: find.byKey(const ValueKey('workspace-search-query')),
              matching: find.byType(TextField),
            );
            await tester.enterText(query, 'сохранённый запрос');
            await tester.pump();
            state.openSearchPanel(currentConversation: true, pins: true);
            await tester.pumpAndSettle();
            expect(find.text('Закреплённые'), findsOneWidget);
            state.openSearchPanel(currentConversation: true);
            await tester.pumpAndSettle();
            expect(
              tester.widget<TextField>(query).controller!.text,
              'сохранённый запрос',
            );
          }
          state.closeSearchPanel();
          await state.openDirectConversation(state.directMessages.single);
          await tester.pumpAndSettle();
          await capture('dm');
          await tester.tap(find.byTooltip('Действия диалога'));
          await tester.pumpAndSettle();
          expect(find.text('Закреплённые'), findsNothing);
          await tester.tap(find.text('Поиск в диалоге'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byKey(const ValueKey('workspace-search-query')),
              matching: find.byType(TextField),
            ),
            'сообщение',
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('workspace-search-submit')),
          );
          await tester.pumpAndSettle();
          expect(api.lastSearchDirectMessageId, 'dm-1');
          state.closeSearchPanel();
          state.toggleWorkspacePanel(WorkspacePanel.audio);
          await tester.pumpAndSettle();
          await capture('audio');
          state.toggleWorkspacePanel(WorkspacePanel.audio);
          state.selectedDirectMessage = null;
          state.selectedChannel = _PortraitApi.voiceChannel;
          state.voiceChannel = _PortraitApi.voiceChannel;
          state.voicePhase = VoicePhase.listener;
          state.notifyListeners();
          await tester.pumpAndSettle();
          await capture('voice');
          // Compact/short IME keeps composer reachable with existing app resize policy.
          state.voiceChannel = null;
          state.voicePhase = VoicePhase.idle;
          state.selectedChannel = _PortraitApi.channel;
          state.notifyListeners();
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();
          await capture('text-ime');
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
  testWidgets('pinned production workspace survives TEXT DM short IME and end', (
    t,
  ) async {
    const rtcEvents = MethodChannel('FlutterWebRTC.Event');
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      rtcEvents,
      (_) async => null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        rtcEvents,
        null,
      ),
    );
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1440, 900);
    addTearDown(t.view.reset);
    await loadUiuxVisualCaptureFonts();
    final root = GlobalKey();
    final room = _PublishedScreenRoom();
    // ignore: invalid_use_of_internal_member
    final created = await RemoteParticipant.createFromInfo(
      room: room,
      info: lk.ParticipantInfo(
        sid: 'sid',
        identity: 'remote',
        name: 'Streamer',
        tracks: [
          lk.TrackInfo(
            sid: 'screen',
            type: lk.TrackType.VIDEO,
            source: lk.TrackSource.SCREEN_SHARE,
            muted: false,
          ),
        ],
      ),
    );
    room.members['remote'] = created.participant;
    final state = _PublishedScreenState(room);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    await t.pumpWidget(
      RepaintBoundary(
        key: root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    (t.state(find.byType(WorkspaceScreen)) as dynamic)
        .workspaceToggleVoiceScreenPin('remote');
    await t.pump();
    await state.selectChannel(_PortraitApi.channel);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byTooltip('Приостановить видео'), findsOneWidget);
    await t.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Написать сообщение…',
      ),
      'Сохранённый черновик',
    );
    for (final size in [
      const Size(1440, 900),
      const Size(390, 480),
      const Size(320, 480),
    ]) {
      for (final ime in [0.0, 180.0]) {
        t.view.physicalSize = size;
        t.view.viewInsets = FakeViewPadding(bottom: ime);
        await t.pump(const Duration(milliseconds: 200));
        expect(t.takeException(), isNull, reason: '$size IME$ime');
        expect(find.text('Сохранённый черновик'), findsOneWidget);
        if (ime > 0) {
          await t.ensureVisible(find.byTooltip('Остановить просмотр'));
          await t.pump();
        }
        await captureUiuxBoundary(
          t,
          find.byKey(root),
          fileName:
              'parity-pinned-workspace-${size.width.toInt()}x${size.height.toInt()}-ime${ime.toInt()}-scale2.png',
          pixelRatio: 1,
        );
      }
    }
    t.view.viewInsets = const FakeViewPadding();
    t.view.physicalSize = const Size(390, 844);
    await state.openDirectConversation(
      const DirectConversation(
        id: 'dm-1',
        participantId: 'account-2',
        displayName: 'Собеседник',
        unreadCount: 0,
      ),
    );
    await t.pump();
    expect(find.byTooltip('Приостановить видео'), findsOneWidget);
    state.toggleWorkspacePanel(WorkspacePanel.profile);
    await t.pump();
    expect(find.byTooltip('Приостановить видео'), findsOneWidget);
    await state.selectChannel(_PortraitApi.voiceChannel);
    await t.pump();
    expect(find.byTooltip('Приостановить видео'), findsNothing);
    await state.selectChannel(_PortraitApi.channel);
    await t.pump();
    expect(find.byTooltip('Приостановить видео'), findsOneWidget);
    room.members.clear();
    state.notifyListeners();
    await t.pump();
    expect(find.byTooltip('Приостановить видео'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await t.runAsync(room.dispose);
  });
}

class _PublishedScreenRoom extends Room {
  final members = <String, RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(members);
}

class _PublishedScreenState extends AppState {
  _PublishedScreenState(this.testRoom) : super(_PortraitApi());
  final Room testRoom;
  String? selectedScreen;
  @override
  Room get room => testRoom;
  @override
  Future<void> selectRemoteScreenForViewing(String? identity) async {
    selectedScreen = identity;
  }
}

class _PortraitApi extends ApiClient {
  @override
  Future<ChatMessage?> findSentText(
    String conversation,
    String client,
    String owner,
  ) async => null;
  @override
  Future<DirectChatMessage?> findSentDirect(
    String conversation,
    String client,
    String owner,
  ) async => null;
  _PortraitApi({
    this.withHistory = false,
    this.historyCount = 1,
    this.paginatedHistory = false,
    this.paginatedDirectHistory = false,
    this.directHistoryCount = 1,
    this.includeDirectMessage = false,
    this.voiceRosters = const [],
    this.extraVoiceChannels = const [],
    this.membersFailures = 0,
    this.memberProfileFailures = 0,
    this.membersResult = const [
      GuildMember(
        id: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
      GuildMember(
        id: 'account-2',
        login: 'peer',
        displayName: 'Собеседник',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
    ],
  });
  final bool withHistory;
  final int historyCount;
  final bool paginatedHistory;
  final bool paginatedDirectHistory;
  int failOlderTextPages = 0;
  int failOlderDirectPages = 0;
  final int directHistoryCount;
  final bool includeDirectMessage;
  final List<VoiceRoomRoster> voiceRosters;
  final List<GuildChannel> extraVoiceChannels;
  int membersFailures;
  int memberProfileFailures;
  final List<GuildMember> membersResult;
  final advancedMessageIds = <String>[];
  int messagePageCalls = 0;
  String? lastMessageAt;
  ChatMessagePage? replyContextPage;
  int directMessagePageCalls = 0;
  String? lastDirectMessageAt;
  DirectChatMessagePage? directReplyContextPage;
  final advancedDirectMessageIds = <String>[];
  String? sentReplyToId;
  String? sentDirectReplyToId;
  List<String> sentMentionIds = const [];
  List<String> sentDirectMentionIds = const [];
  List<String> sentAttachmentIds = const [];
  List<String> sentDirectAttachmentIds = const [];
  int failTextSends = 0;
  final textSendIds = <String>[];
  int textEditConflicts = 0;
  int latestTextRevision = 1;
  bool deleteTextOnConflict = false;
  bool latestTextDeleted = false;
  final textEditRevisions = <int>[];
  final textEditMentionIds = <List<String>>[];
  String? lastSearchQuery;
  String? lastSearchDirectMessageId;
  final searchRequests = <(String, String?, String?)>[];
  Completer<SearchMessagePage>? searchGate;
  SearchMessagePage? searchResultPage;
  bool emptySearchResults = false;
  bool failAdminUpdate = false;
  bool failResetLink = false;
  bool failAudit = false;
  bool emptyAudit = false;
  Completer<void>? auditGate;
  bool paginateAdminAccounts = false;
  final adminAccountCursors = <String?>[];
  final adminUpdates = <(String, String, bool)>[];

  static const channel = GuildChannel(
    id: 'channel-1',
    name: 'общий',
    kind: ChannelKind.text,
    admissionClosed: false,
    unreadCount: 4,
    mentionCount: 2,
  );
  static const voiceChannel = GuildChannel(
    id: 'voice-1',
    name: 'комната',
    kind: ChannelKind.voice,
    admissionClosed: false,
    unreadCount: 9,
    mentionCount: 3,
  );
  static const secondVoiceChannel = GuildChannel(
    id: 'voice-2',
    name: 'комната 2',
    kind: ChannelKind.voice,
    admissionClosed: false,
    unreadCount: 0,
    mentionCount: 0,
  );

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<http.StreamedResponse> maintenanceEvents() async =>
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        200,
        headers: {'content-type': 'text/event-stream'},
      );

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');
  @override
  Future<PermissionSnapshot> loadPermissions() async => PermissionSnapshot(
    accountId: 'account-1',
    role: GuildRole.member,
    revision: 1,
    values: {for (final permission in GuildPermission.values) permission: true},
  );

  @override
  Future<OwnProfile> ownProfile() async => const OwnProfile(
    accountId: 'account-1',
    login: 'member',
    displayName: 'Участник',
    role: 'MEMBER',
  );

  @override
  Future<ChannelTopology> topology() async => ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [channel, voiceChannel, ...extraVoiceChannels],
      ),
    ],
  );

  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() async => voiceRosters;

  @override
  Future<http.StreamedResponse> voiceRosterEvents() async {
    final payload = jsonEncode({
      'channels': voiceRosters
          .map(
            (room) => {
              'channel_id': room.channelId,
              'participants': room.participants
                  .map(
                    (member) => {
                      'account_id': member.accountId,
                      'display_name': member.displayName,
                      'screen_sharing': member.screenSharing,
                      'microphone_muted': member.microphoneMuted,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: $payload\n\n')),
      200,
    );
  }

  @override
  Future<List<GuildMember>> members() async {
    if (membersFailures > 0) {
      membersFailures--;
      throw const ApiFailure('Список участников временно недоступен.');
    }
    return membersResult;
  }

  @override
  Future<GuildMember> memberProfile(String accountId) async {
    if (memberProfileFailures > 0) {
      memberProfileFailures--;
      throw const ApiFailure('Не удалось загрузить профиль участника.');
    }
    return membersResult.firstWhere((member) => member.id == accountId);
  }

  @override
  Future<SearchMessagePage> searchMessages(
    String query, {
    String? channelId,
    String? directMessageId,
    String? before,
    int limit = 20,
  }) async {
    lastSearchQuery = query;
    lastSearchDirectMessageId = directMessageId;
    searchRequests.add((query, channelId, directMessageId));
    final gate = searchGate;
    if (gate != null) return gate.future;
    final resultPage = searchResultPage;
    if (resultPage != null) return resultPage;
    return SearchMessagePage(
      messages: emptySearchResults
          ? const []
          : [
              SearchMessage(
                id: 'message-1',
                kind: SearchMessageKind.channel,
                conversationId: channelId ?? channel.id,
                authorId: 'account-1',
                body: 'Найденный текст',
                createdAt: DateTime.utc(2026, 9, 25),
                revision: 1,
              ),
            ],
    );
  }

  @override
  Future<AdminAuditPage> listAdminAudit({
    String? before,
    int limit = 100,
  }) async {
    await auditGate?.future;
    if (failAudit) {
      throw const ApiFailure('Не удалось загрузить журнал аудита.');
    }
    if (emptyAudit) return const AdminAuditPage(events: []);
    return before == null
        ? AdminAuditPage(
            events: [
              AdminAuditEvent(
                id: 'event-1',
                eventType: 'CHANNEL_CREATED',
                createdAt: DateTime.utc(2026, 9, 26, 10),
                actorUserId: 'account-1',
                actorDisplayName: 'Admin',
                actorLogin: 'admin',
              ),
            ],
            nextCursor: 'cursor-older',
          )
        : AdminAuditPage(
            events: [
              AdminAuditEvent(
                id: 'event-older',
                eventType: 'PASSWORD_RESET_APPLIED',
                createdAt: DateTime.utc(2026, 9, 25, 10),
              ),
            ],
          );
  }

  @override
  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async {
    adminAccountCursors.add(cursor);
    return AdminAccountPage(
      accounts: [
        AdminAccount(
          accountId: cursor == null ? 'account-2' : 'account-3',
          login: cursor == null ? 'peer' : 'peer-2',
          displayName: cursor == null ? 'Собеседник' : 'Другой собеседник',
          role: 'MEMBER',
          blocked: false,
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 26, 11),
        ),
      ],
      nextCursor: paginateAdminAccounts && cursor == null
          ? 'cursor-next'
          : null,
    );
  }

  @override
  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
    DateTime? expectedUpdatedAt,
  }) async {
    adminUpdates.add((accountId, role, blocked));
    if (failAdminUpdate) {
      throw const ApiFailure('Запрос отклонён сервером.');
    }
  }

  @override
  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) async {
    if (failResetLink) throw const ApiFailure('Не удалось создать ссылку.');
    return AdminPasswordResetLink(
      url: 'https://v.bootybay.ru/reset-password#token=one-time',
      expiresAt: DateTime.utc(2026, 9, 26, 12),
    );
  }

  @override
  Future<List<DirectConversation>> directMessages() async =>
      includeDirectMessage
      ? const [
          DirectConversation(
            id: 'dm-1',
            participantId: 'account-2',
            displayName: 'Собеседник',
            unreadCount: 1,
          ),
        ]
      : const [];

  @override
  Future<List<DirectChatMessage>> directMessageHistory(String id) async =>
      List.generate(
        paginatedDirectHistory ? directHistoryCount : 1,
        (index) => DirectChatMessage(
          id: paginatedDirectHistory ? 'dm-message-$index' : 'dm-message-1',
          directMessageId: id,
          authorId: 'account-2',
          body: paginatedDirectHistory
              ? 'Личное сообщение $index'
              : 'Исходное личное сообщение',
          createdAt: DateTime.utc(2026, 9, 25).add(Duration(minutes: index)),
          deleted: false,
          revision: 1,
        ),
      );

  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async {
    directMessagePageCalls++;
    if (before != null && failOlderDirectPages > 0) {
      failOlderDirectPages--;
      throw const ApiFailure('Сеть недоступна');
    }
    if (at != null) {
      lastDirectMessageAt = at;
      if (directReplyContextPage != null) return directReplyContextPage!;
    }
    if (paginatedDirectHistory && before != null) {
      return DirectChatMessagePage(
        messages: List.generate(
          12,
          (index) => DirectChatMessage(
            id: 'older-dm-message-$index',
            directMessageId: id,
            authorId: 'account-2',
            body: index == 0
                ? 'Более старое личное сообщение 0 ${'длинный текст ' * 16}'
                : 'Более старое личное сообщение $index',
            createdAt: DateTime.utc(2026, 9, 24).add(Duration(minutes: index)),
            deleted: false,
            revision: 1,
          ),
        ),
        nextCursor: 'oldest-dm-page',
      );
    }
    return DirectChatMessagePage(
      messages: await directMessageHistory(id),
      nextCursor: paginatedDirectHistory ? 'older-dm-page' : null,
    );
  }

  @override
  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    advancedDirectMessageIds.add(messageId);
  }

  @override
  Future<DirectChatMessage> sendDirectMessage(
    String directMessageId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    sentDirectReplyToId = replyToId;
    sentDirectMentionIds = mentionUserIds;
    sentDirectAttachmentIds = attachmentIds;
    return DirectChatMessage(
      id: 'sent-dm-message',
      directMessageId: directMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<List<ChatMessage>> messages(String channelId) async => withHistory
      ? List.generate(
          historyCount,
          (index) => ChatMessage(
            id: 'message-$index',
            channelId: channelId,
            authorId: 'account-1',
            body: latestTextDeleted
                ? ''
                : index == historyCount - 1
                ? 'Последнее сообщение'
                : 'Сообщение $index',
            createdAt: DateTime.utc(2026, 9, 25).add(Duration(minutes: index)),
            deleted: latestTextDeleted,
            revision: latestTextRevision,
          ),
        )
      : const [];

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    messagePageCalls++;
    if (before != null && failOlderTextPages > 0) {
      failOlderTextPages--;
      throw const ApiFailure('Сеть недоступна');
    }
    if (at != null) {
      lastMessageAt = at;
      if (replyContextPage != null) return replyContextPage!;
    }
    if (paginatedHistory && before != null) {
      return ChatMessagePage(
        messages: List.generate(
          12,
          (index) => ChatMessage(
            id: 'older-message-$index',
            channelId: channelId,
            authorId: 'account-2',
            body: index == 0
                ? 'Более старое сообщение 0 ${'длинный текст ' * 16}'
                : 'Более старое сообщение $index',
            createdAt: DateTime.utc(2026, 9, 24).add(Duration(minutes: index)),
            deleted: false,
            revision: 1,
          ),
        ),
        nextCursor: 'oldest-page',
      );
    }
    return ChatMessagePage(
      messages: await messages(channelId),
      nextCursor: paginatedHistory ? 'older-page' : null,
    );
  }

  @override
  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    textSendIds.add(clientMessageId);
    if (failTextSends > 0) {
      failTextSends--;
      throw const ApiFailure('Отправка не подтверждена.');
    }
    sentReplyToId = replyToId;
    sentMentionIds = mentionUserIds;
    sentAttachmentIds = attachmentIds;
    return ChatMessage(
      id: 'sent-message',
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25, 1),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    textEditRevisions.add(expectedRevision);
    textEditMentionIds.add(mentionUserIds);
    if (textEditConflicts > 0) {
      textEditConflicts--;
      latestTextRevision = expectedRevision + 1;
      latestTextDeleted = deleteTextOnConflict;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return ChatMessage(
      id: messageId,
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25, 1),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    advancedMessageIds.add(messageId);
  }
}
