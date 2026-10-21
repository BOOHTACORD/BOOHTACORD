import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/header/component.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/quality/picker.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_message_navigation/component.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'compact header actions and full name remain reachable at $width',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 480);
        addTearDown(t.view.reset);
        var activated = 0;
        final title = List.filled(12, 'Длинное название').join(' ');
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 480),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: WorkspaceHeader(
                  icon: Icons.tag,
                  title: title,
                  subtitle: 'Текстовый канал',
                  mobileConversationLayout: true,
                  onToggleNavigation: () {},
                  onOpenMembers: () {},
                  trailing: IconButton(
                    tooltip: 'Действия диалога',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () => activated++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byTooltip(title), findsOneWidget);
        await t.tap(find.byTooltip('Действия диалога'));
        expect(activated, 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'screen quality shows the selected profile without recommended Apply',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QualityPicker(
                quality: const ScreenShareQuality(
                  resolution: 720,
                  frameRate: 30,
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Рекомендуемый профиль'), findsNothing);
      expect(
        find.byKey(const ValueKey('apply-recommended-screen-profile')),
        findsNothing,
      );
      expect(find.textContaining('720p · 30 FPS'), findsOneWidget);
    },
  );

  testWidgets('DM navigation uses authenticated avatar and preserves unread', (
    t,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    state.directMessages = const [
      DirectConversation(
        id: 'dm',
        participantId: 'person',
        displayName: 'Анна Иванова',
        unreadCount: 3,
      ),
    ];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceDirectMessageNavigation(state: state),
          ),
        ),
      ),
    );
    expect(find.byType(AuthenticatedAvatar), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Анна Иванова'), findsOneWidget);
  });
}
