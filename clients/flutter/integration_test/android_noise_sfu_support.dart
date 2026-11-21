import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_support/app_resume_wait.dart';
import 'issue689_support.dart';
import 'noise_runtime_diagnostic.dart';

Future<void> waitForNoiseActive(WidgetTester tester, AppState app) async {
  try {
    await waitFor(tester, () => app.noiseSuppressionRuntime.status == 'active');
  } on TestFailure {
    fail(
      'RNNoise did not become active: ${noiseRuntimeDiagnostic(app.noiseSuppressionRuntime)}',
    );
  }
}

Future<void> verifyContinuedNoise(WidgetTester tester, AppState app) async {
  final before = app.noiseSuppressionRuntime.processedFrames;
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
  await tester.pump();
  final state = app.noiseSuppressionRuntime;
  final diagnostic = noiseRuntimeDiagnostic(state);
  expect(state.status, 'active', reason: diagnostic);
  expect(state.processedFrames, greaterThan(before), reason: diagnostic);
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
