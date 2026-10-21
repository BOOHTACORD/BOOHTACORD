import 'dart:async';

import 'package:flutter/material.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/message_timestamp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/members_panel/profile_overlay.dart';

import '../uiux_2026/capture_support.dart';

class _Api extends ApiClient {
  final response = Completer<GuildMember>();
  @override
  Future<GuildMember> memberProfile(String id) => response.future;
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'actual profile overlay bounds, Back and late response at $width',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 480);
        addTearDown(t.view.reset);
        await loadUiuxVisualCaptureFonts();
        final api = _Api(), root = GlobalKey();
        final state = AppState(api);
        addTearDown(state.dispose);
        await t.pumpWidget(
          RepaintBoundary(
            key: root,
            child: MaterialApp(
              theme: guildTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  viewInsets: const EdgeInsets.only(bottom: 180),
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => openMemberProfileOverlay(
                      context: context,
                      state: state,
                      memberId: 'person',
                      anchor: () => Rect.fromLTWH(width - 56, 430, 48, 44),
                      onContext: (_) {},
                    ),
                    child: const Text('Открыть'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Открыть'));
        await t.pumpAndSettle();
        final popup = find.byKey(const ValueKey('member-profile-popover'));
        expect(popup, findsOneWidget);
        final rect = t.getRect(popup);
        expect(rect.left, greaterThanOrEqualTo(8));
        expect(rect.right, lessThanOrEqualTo(width - 8));
        expect(t.takeException(), isNull);
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(popup, findsNothing);
        api.response.complete(
          const GuildMember(
            id: 'person',
            login: 'synthetic',
            displayName: 'Поздний профиль',
            role: 'MEMBER',
            presence: MemberPresence.offline,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Поздний профиль'), findsNothing);
        expect(t.takeException(), isNull);
        // Reopen with completed data, then navigation must dismiss the same route.
        await t.tap(find.text('Открыть'));
        await t.pumpAndSettle();
        expect(find.text('Поздний профиль'), findsOneWidget);
        final viewport = t.getRect(
          find
              .ancestor(of: popup, matching: find.byType(SingleChildScrollView))
              .first,
        );
        expect(viewport.top, greaterThanOrEqualTo(32));
        expect(viewport.bottom, lessThanOrEqualTo(292));
        await captureUiuxBoundary(
          t,
          find.byKey(root),
          fileName: 'parity-profile-${width.toInt()}x480-ime-scale2.png',
          pixelRatio: 1,
        );
        state.toggleWorkspacePanel(WorkspacePanel.profile);
        await t.pumpAndSettle();
        expect(popup, findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  test(
    'full timestamp contains local seconds, zone and numeric UTC offset',
    () {
      // Checked alongside grouped TEXT/DM policy, with a non-minute timestamp.
      final value = DateTime.utc(2026, 10, 21, 12, 34, 56).toLocal();
      expect(MessageTimestamp.full(value), contains(':56'));
      expect(MessageTimestamp.full(value), contains(value.timeZoneName));
      expect(
        MessageTimestamp.full(value),
        matches(RegExp(r'UTC[+-][0-9]{2}:[0-9]{2}')),
      );
      expect(
        MessageTimestamp.short(value),
        matches(RegExp(r'^[0-9]{2}:[0-9]{2}$')),
      );
    },
  );
}
