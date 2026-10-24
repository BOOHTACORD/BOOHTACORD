import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/show_screen_share_setup/component.dart';
import 'package:boohtacord_desktop/src/features/workspace/navigation/favorites/preferences.dart';

class QaTls extends HttpOverrides {
  QaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4810 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('owned API authentication and native workspace visual smoke', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE');
    const pin = String.fromEnvironment('QA_CERT_SHA256');
    const password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4810/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError(
        'Owned QA endpoint, certificate pin and disposable credentials required',
      );
    }
    HttpOverrides.global = QaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('server_url', origin);
    final api = ApiClient();
    final state = AppState(api);
    addTearDown(state.dispose);
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.runAsync(state.initialize);
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.signedOut);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('native-auth');
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'qa_admin');
    await tester.enterText(fields.at(1), password);
    // Dismiss the software keyboard before activating the visible login action.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Войти').last);
    for (
      var attempt = 0;
      attempt < 120 && state.phase != AppPhase.ready;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(state.phase, AppPhase.ready);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    // This stack starts empty. Seed the channel used by later navigation checks
    // through the actual authenticated admin API, not a widget fixture.
    if (state.topology!.categories.isEmpty) {
      await tester.runAsync(() async {
        await api.createCategory('Native QA');
        await state.refreshTopology();
        final category = state.topology!.categories.firstWhere(
          (value) => value.name == 'Native QA',
        );
        await api.createChannel(
          categoryId: category.id,
          name: 'Native QA Text',
          kind: ChannelKind.text,
        );
        await state.refreshTopology();
      });
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('native-navigation');
    // ADR-029: a fresh installation defaults to the product support peer.
    // Opening the chat cannot publish anything before explicit consent.
    await tester.tap(find.byTooltip('Помощь и обратная связь'));
    for (var attempt = 0; attempt < 120 && state.supportOpening; attempt++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
    expect(state.supportAvailable, isTrue);
    expect(state.supportContact.product, isTrue);
    expect(state.supportContact.consentRequired, isTrue);
    expect(find.text('Согласен на публикацию'), findsOneWidget);
    expect(state.selectedDirectMessage, isNotNull);
    expect(find.textContaining('общедоступны'), findsOneWidget);
    await binding.takeScreenshot('native-public-support-default');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
    await binding.takeScreenshot('native-workspace');
    final channel = state.topology!.categories
        .expand((c) => c.channels)
        .firstWhere((c) => c.kind == ChannelKind.text);
    await tester.runAsync(() => state.selectChannel(channel));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Действия диалога'));
    await tester.pumpAndSettle();
    expect(find.text('Закреплённые'), findsOneWidget);
    await tester.tap(find.text('Поиск в диалоге'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('workspace-search-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'current',
    );
    await binding.takeScreenshot('native-context-search');
    await tester.tap(find.byTooltip('Закрыть поиск'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
    expect(find.byTooltip('Действия диалога').hitTestable(), findsOneWidget);

    // Exercise the changed production chooser on a real native surface. Cancel
    // before capture: this confirms UI behaviour, not MediaProjection/media.
    final selectedQuality = state.screenShareSelectedQuality;
    final setup = workspaceShowScreenShareSetup(
      tester.element(find.byType(Scaffold).last),
      state,
    );
    await tester.pumpAndSettle();
    final textMode = find.byKey(const ValueKey('screen-content-text'));
    final motionMode = find.byKey(const ValueKey('screen-content-motion'));
    await tester.ensureVisible(textMode);
    await tester.tap(textMode);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(textMode).selected, isTrue);
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();
    Finder frameRateSelector() => find.descendant(
      of: find.byKey(const ValueKey('frame-rate-segments')),
      matching: find.byType(SegmentedButton<int>),
    );
    expect(tester.widget<SegmentedButton<int>>(frameRateSelector()).selected, {
      selectedQuality.frameRate,
    });
    await tester.ensureVisible(textMode);
    await binding.takeScreenshot('native-screen-text-independent-fps');
    await tester.tap(motionMode);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(motionMode).selected, isTrue);
    expect(tester.widget<SegmentedButton<int>>(frameRateSelector()).selected, {
      selectedQuality.frameRate,
    });
    await binding.takeScreenshot('native-screen-motion-independent-fps');
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await setup;
    expect(state.screenShareSelectedQuality, selectedQuality);
    expect(state.screenSharePhase, ScreenSharePhase.idle);
    expect(tester.takeException(), isNull);
    for (final panel in [
      WorkspacePanel.profile,
      WorkspacePanel.audio,
      WorkspacePanel.admin,
    ]) {
      state.toggleWorkspacePanel(panel);
      await tester.pumpAndSettle();
      expect(state.workspacePanel, panel);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('native-${panel.name}');
      if (panel == WorkspacePanel.audio) {
        final scrollable = find.descendant(
          of: find.byKey(const ValueKey('audio-settings-list')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Дополнительно'),
          120,
          scrollable: scrollable,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Дополнительно')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Дополнительно'));
        await tester.pumpAndSettle();
        final processing = find.text('Автоматическая регулировка усиления');
        expect(processing, findsOneWidget);
        final mounted = tester.element(processing);
        await binding.takeScreenshot('native-audio-advanced');
        await Scrollable.ensureVisible(
          tester.element(find.text('Дополнительно')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Дополнительно'));
        await tester.pumpAndSettle();
        expect(mounted.mounted, isTrue);
      }
    }
    state.showChannels();
    await tester.pumpAndSettle();
    final channelForFavorites = state.topology!.categories
        .expand((category) => category.channels)
        .firstWhere((channel) => channel.name == 'Native QA Text');
    final addFavorite = find.byTooltip(
      'Добавить в избранное: ${channelForFavorites.name}',
    );
    await tester.ensureVisible(addFavorite);
    await tester.tap(addFavorite);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        ValueKey('workspace-favorite-shortcut:${channelForFavorites.id}'),
      ),
      findsOneWidget,
    );
    expect(
      await ChannelFavoritesPreferences(
        accountId: state.profile!.accountId,
        baseUrl: origin,
      ).read(),
      contains(channelForFavorites.id),
    );
    await binding.takeScreenshot('native-channel-favorites');
    state.voicePhase = VoicePhase.error;
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('connection-status-card')),
      findsOneWidget,
    );
    expect(find.text('Голос не подключён'), findsOneWidget);
    await binding.takeScreenshot('native-connection-status');
    await tester.runAsync(state.logout);
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.signedOut);
    await binding.takeScreenshot('native-signed-out');
  });
}
