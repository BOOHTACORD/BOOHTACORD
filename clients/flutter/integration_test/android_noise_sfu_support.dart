import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_support/app_resume_wait.dart';

Future<void> verifyContinuedNoise(WidgetTester tester, AppState app) async {
  final before = app.noiseSuppressionRuntime.processedFrames;
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
  await tester.pump();
  expect(app.noiseSuppressionRuntime.status, 'active');
  expect(app.noiseSuppressionRuntime.processedFrames, greaterThan(before));
}

Future<void> openAudioSettings(WidgetTester tester, AppState app) async {
  await tester.runAsync(
    () => waitForAppResume(
      readLifecycleState: () => tester.binding.lifecycleState,
      timeout: const Duration(minutes: 75),
    ),
  );
  if (app.workspacePanel != WorkspacePanel.audio) {
    app.toggleWorkspacePanel(WorkspacePanel.audio);
  }
  await tester.pumpAndSettle();
  final closeNavigation = find.byTooltip('Закрыть навигацию');
  if (closeNavigation.evaluate().isNotEmpty) {
    await tester.tap(closeNavigation);
    await tester.pumpAndSettle();
  }
}
