import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_dock_button/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/screen_setup_launchers.dart';

void main() {
  testWidgets('both screen launchers have one visible native target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IconButton(
                tooltip: 'Начать демонстрацию экрана',
                onPressed: () {},
                icon: const Icon(Icons.screen_share_outlined),
              ),
              WorkspaceVoiceDockButton(
                tooltip: 'Начать демонстрацию экрана',
                icon: Icons.screen_share_outlined,
                danger: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    for (final dock in [false, true]) {
      final trigger = await waitForScreenSetupLauncher(tester, dock: dock);
      expect(trigger, findsOneWidget, reason: 'dock=$dock');
    }
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  testWidgets('waits for the frame after voice becomes connected', (
    tester,
  ) async {
    var ready = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            if (!ready) {
              Future<void>.delayed(const Duration(milliseconds: 50), () {
                setState(() => ready = true);
              });
            }
            return ready
                ? IconButton(
                    tooltip: 'Начать демонстрацию экрана',
                    onPressed: () {},
                    icon: const Icon(Icons.screen_share_outlined),
                  )
                : const SizedBox();
          },
        ),
      ),
    );
    expect(
      await waitForScreenSetupLauncher(tester, dock: false),
      findsOneWidget,
    );
  });

  testWidgets('rejects duplicate launchers and a missing launcher', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (var i = 0; i < 2; i++)
              IconButton(
                tooltip: 'Начать демонстрацию экрана',
                onPressed: () {},
                icon: const Icon(Icons.screen_share_outlined),
              ),
          ],
        ),
      ),
    );
    await expectLater(
      () => waitForScreenSetupLauncher(tester, dock: false),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          'launcher_not_unique',
        ),
      ),
    );
    await expectLater(
      () => waitForScreenSetupLauncher(
        tester,
        dock: true,
        timeout: Duration.zero,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          'launcher_not_visible',
        ),
      ),
    );
  });
}
