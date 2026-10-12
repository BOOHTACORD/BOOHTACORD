import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/guild_header.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/user_footer/lifecycle/widget.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [280.0, 320.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('guild header grows for text $scale at width $width', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: WorkspaceGuildHeader(
                      guildName: 'BOOHTACORD',
                      compact: true,
                      memberCount: 6,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final header = tester.getRect(
          find.byKey(const ValueKey('navigation-guild-header')),
        );
        final member = tester.getRect(find.text('6 участников'));
        expect(member.bottom, lessThanOrEqualTo(header.bottom));
        expect(header.height, scale == 1 ? 64 : greaterThanOrEqualTo(72));
        await tester.tap(find.byTooltip('Закрыть навигацию'));
        expect(tester.takeException(), isNull);
      });
      testWidgets('profile footer grows for text $scale at width $width', (
        tester,
      ) async {
        final state = AppState(ApiClient());
        state.user = const SessionUser(
          accountId: 'fixture',
          role: 'ADMINISTRATOR',
        );
        state.profile = const OwnProfile(
          accountId: 'fixture',
          login: 'fixture',
          displayName: 'Проверка доступности',
          role: 'ADMINISTRATOR',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: WorkspaceUserFooter(state: state),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final footer = tester.getRect(find.byType(WorkspaceUserFooter));
        final role = tester.getRect(find.text('Администратор'));
        expect(role.bottom, lessThanOrEqualTo(footer.bottom));
        expect(footer.height, scale == 1 ? 64 : greaterThanOrEqualTo(64));
        await tester.tap(find.byTooltip('Настройки аккаунта'));
        await tester.pumpAndSettle();
        expect(find.text('Администрирование'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      });
    }
  }
}
