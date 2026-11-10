import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:boohtacord_desktop/src/features/updates/required_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'required_action_support.dart';

import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  testWidgets(
    'failed external launch shows a retryable error inside the required gate',
    (tester) async {
      final original = UrlLauncherPlatform.instance;
      final launcher = FakeLauncher()..succeeds = false;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      const policy = UpdatePolicy(
        revision: 1,
        state: UpdatePolicyState.published,
        target: UpdateTarget(
          releaseId: 'r5',
          releaseOrder: 5,
          minimumReleaseOrder: 4,
          arches: ['arm64'],
          actionKind: 'open_instructions',
          actionUrl: 'https://github.com/BOOHTACORD/BOOHTACORD/releases',
        ),
      );
      final updates = UpdateController(
        api: FakeUpdateApi(policy),
        identity: const NativeUpdateIdentity(
          LocalUpdateIdentity(
            releaseId: 'r2',
            releaseOrder: 2,
            platform: 'windows',
          ),
          UpdateSelector.windows('x64'),
          UpdateEnvironment(osVersion: '10', arch: 'x64'),
        ),
      )..policy = policy;
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RequiredUpdateGuard(
            updates: updates,
            appBusy: false,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Не удалось открыть страницу обновления. Попробуйте ещё раз.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('required-update-gate')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
