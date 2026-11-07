import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/user_footer/component.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'join_sounds/fixture.dart';
import 'join_sounds/driver.dart';
import 'join_sounds/capture.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'profile uploads, enables, previews and deletes a private melody',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError('Owned QA endpoint required');
      }
      HttpOverrides.global = QaTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final original = FileSelectorPlatform.instance, files = QaSoundFiles();
      FileSelectorPlatform.instance = files;
      addTearDown(() => FileSelectorPlatform.instance = original);
      final preferences = await SharedPreferences.getInstance();
      final previousServer = preferences.getString('server_url');
      addTearDown(() async {
        if (previousServer == null) {
          await preferences.remove('server_url');
        } else {
          await preferences.setString('server_url', previousServer);
        }
      });
      await preferences.setString('server_url', origin);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: BoohtacordApp(state: state),
        ),
      );
      await tester.runAsync(state.initialize);
      await tester.runAsync(
        () => state.authenticate('qa_admin', password, register: false),
      );
      await tester.pumpAndSettle();
      expect(state.phase, AppPhase.ready);
      for (
        var i = 0;
        i < 100 && state.voice.sounds.preferences?.ready != true;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(state.voice.sounds.preferences!.ready, isTrue);
      await tester.runAsync(() => state.voice.sounds.api!.remove());
      await tester.tap(
        find
            .descendant(
              of: find.byType(WorkspaceUserFooter),
              matching: find.text('qa_admin'),
            )
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();
      final controls = QaSoundProfileDriver(tester);

      await controls.settled();
      if (state.voice.sounds.legacy.blocked) {
        await controls.tap('Использовать настройки аккаунта');
      }
      expect(state.voice.sounds.allows('joined'), isTrue);
      await controls.tap('Загрузить мелодию');
      expect(files.calls, 1);
      final saved = await tester.runAsync(
        () => state.voice.sounds.api!.current(),
      );
      expect(saved?['enabled'], false);
      expect(saved?['id'], isNotEmpty);
      await controls.tap('Использовать при входе в канал');
      expect(
        (await tester.runAsync(
          () => state.voice.sounds.api!.current(),
        ))?['enabled'],
        true,
      );
      await controls.tap('Прослушать мелодию');
      expect(find.textContaining('Не удалось воспроизвести'), findsNothing);
      await tester.runAsync(
        () => captureQaSoundWidgets(capture, 'profile-melody'),
      );
      await controls.tap('Удалить мелодию');
      expect(
        await tester.runAsync(() => state.voice.sounds.api!.current()),
        isNull,
      );
      expect(find.text('Прослушать мелодию'), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint(
        'JOIN_SOUND_FULL_WORKSPACE_PASS upload=real-http-worker preview=soloud picker=synthetic',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
