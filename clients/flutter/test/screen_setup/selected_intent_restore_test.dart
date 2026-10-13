import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/show_screen_share_setup/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingIntentState extends AppState {
  _PendingIntentState() : super(ApiClient());
  @override
  ScreenSharePhase get screenSharePhase => ScreenSharePhase.sharing;
  @override
  ScreenShareQuality get screenShareQuality =>
      const ScreenShareQuality(resolution: 1080, frameRate: 30);
  @override
  ScreenShareQuality get screenShareSelectedQuality =>
      const ScreenShareQuality(resolution: 1080, frameRate: 60);
}

void main() {
  testWidgets(
    'workspace chooser restores chosen 60 FPS while applied profile remains 30 FPS',
    (tester) async {
      final state = _PendingIntentState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => workspaceShowScreenShareSetup(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final selector = tester.widget<SegmentedButton<int>>(
        find.descendant(
          of: find.byKey(const ValueKey('frame-rate-segments')),
          matching: find.byType(SegmentedButton<int>),
        ),
      );
      expect(selector.selected, {60});
      expect(state.screenShareQuality.frameRate, 30);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
