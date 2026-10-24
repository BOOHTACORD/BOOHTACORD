import 'package:boohtacord_desktop/src/features/workspace/navigation/favorites/preferences.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/channel_navigation/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'channels can be favorited and restored as navigation shortcuts',
    (tester) async {
      final state = _state();

      await _pumpNavigation(tester, state, TargetPlatform.android);
      expect(find.text('ИЗБРАННОЕ'), findsNothing);

      final favoriteButton = find.byTooltip('Добавить в избранное: General');
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      expect(find.text('ИЗБРАННОЕ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workspace-favorite-shortcut:text-general')),
        findsOneWidget,
      );
      expect(find.byTooltip('Убрать из избранного: General'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('workspace-channel-favorite:text-general'),
              ),
            )
            .width,
        greaterThanOrEqualTo(44),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpNavigation(tester, state, TargetPlatform.android);
      expect(
        find.byKey(const ValueKey('workspace-favorite-shortcut:text-general')),
        findsOneWidget,
      );
    },
  );

  testWidgets('favorites follow channel topology order and prune removed ids', (
    tester,
  ) async {
    final state = _state();
    final preferences = ChannelFavoritesPreferences(
      accountId: 'account-1',
      baseUrl: state.serverUrl,
    );
    await preferences.save({'text-random', 'text-general'});

    await _pumpNavigation(tester, state, TargetPlatform.android);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('workspace-favorite-shortcut:text-general')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('workspace-favorite-shortcut:text-random')),
    );
    expect(first.dy, lessThan(second.dy));

    state.topology = const ChannelTopology(
      revision: 2,
      categories: [
        ChannelCategory(
          id: 'category-main',
          name: 'General',
          channels: [
            GuildChannel(
              id: 'text-general',
              name: 'General',
              kind: ChannelKind.text,
              admissionClosed: false,
            ),
          ],
        ),
      ],
    );
    await _pumpNavigation(tester, state, TargetPlatform.android);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-favorite-shortcut:text-random')),
      findsNothing,
    );
    expect(await preferences.read(), {'text-general'});
  });

  testWidgets('unfavorited channel action appears on hover on desktop', (
    tester,
  ) async {
    final state = _state();

    await _pumpNavigation(tester, state, TargetPlatform.macOS);
    final favorite = find.byTooltip('Добавить в избранное: General');
    expect(favorite, findsNothing);

    final row = find.byKey(
      const ValueKey('workspace-channel-row:text-general'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(row));
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    expect(favorite, findsOneWidget);
  });

  testWidgets('unfavorited channel action appears when focused on desktop', (
    tester,
  ) async {
    final state = _state();

    await _pumpNavigation(tester, state, TargetPlatform.macOS);
    final favorite = find.byTooltip('Добавить в избранное: General');
    expect(favorite, findsNothing);

    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (favorite.evaluate().isNotEmpty) break;
    }
    expect(favorite, findsOneWidget);
  });

  testWidgets('favorites navigation visual capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();
    final state = _state();
    await ChannelFavoritesPreferences(
      accountId: 'account-1',
      baseUrl: state.serverUrl,
    ).save({'text-general', 'voice-lounge'});

    const boundaryKey = ValueKey('channel-favorites-capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 340,
            height: 860,
            child: Material(child: WorkspaceChannelNavigation(state: state)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ИЗБРАННОЕ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-favorite-shortcut:voice-lounge')),
      findsOneWidget,
    );
    await captureUiuxBoundary(
      tester,
      find.byKey(boundaryKey),
      fileName: 'flutter-channel-favorites-1440x900.png',
      pixelRatio: 1,
    );
  });

  testWidgets('mobile favorites navigation visual capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();
    final state = _state();
    await ChannelFavoritesPreferences(
      accountId: 'account-1',
      baseUrl: state.serverUrl,
    ).save({'text-general', 'voice-lounge'});

    const boundaryKey = ValueKey('channel-favorites-mobile-capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.android),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Material(child: WorkspaceChannelNavigation(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ИЗБРАННОЕ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-favorite-shortcut:voice-lounge')),
      findsOneWidget,
    );
    final favoriteTarget = tester.getSize(
      find.byKey(const ValueKey('workspace-channel-favorite:text-general')),
    );
    expect(favoriteTarget.width, greaterThanOrEqualTo(44));
    expect(favoriteTarget.height, greaterThanOrEqualTo(44));
    await captureUiuxBoundary(
      tester,
      find.byKey(boundaryKey),
      fileName: 'flutter-channel-favorites-mobile-393x852.png',
      pixelRatio: 1,
    );
  });
}

AppState _state() {
  final state = AppState(ApiClient());
  state.profile = const OwnProfile(
    accountId: 'account-1',
    login: 'alice',
    displayName: 'Алиса',
    role: 'MEMBER',
  );
  state.topology = const ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-main',
        name: 'General',
        channels: [
          GuildChannel(
            id: 'text-general',
            name: 'General',
            kind: ChannelKind.text,
            admissionClosed: false,
          ),
          GuildChannel(
            id: 'text-random',
            name: 'Random',
            kind: ChannelKind.text,
            admissionClosed: false,
          ),
          GuildChannel(
            id: 'voice-lounge',
            name: 'Lounge',
            kind: ChannelKind.voice,
            admissionClosed: false,
          ),
        ],
      ),
    ],
  );
  return state;
}

Future<void> _pumpNavigation(
  WidgetTester tester,
  AppState state,
  TargetPlatform platform,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: guildTheme().copyWith(platform: platform),
      home: SizedBox(
        width: 340,
        height: 860,
        child: Material(child: WorkspaceChannelNavigation(state: state)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
