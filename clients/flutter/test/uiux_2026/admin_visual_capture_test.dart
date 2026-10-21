import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/admin/shell/section_tabs.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import '../admin_accessibility/api_fixture.dart';
import 'capture_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final profile in [
    (
      name: 'mobile',
      size: const Size(393, 852),
      pixelRatio: 3.0,
      textScale: 1.0,
      compact: true,
    ),
    (
      name: 'mobile-large-text',
      size: const Size(393, 852),
      pixelRatio: 3.0,
      textScale: 2.0,
      compact: true,
    ),
    (
      name: 'desktop',
      size: const Size(1440, 900),
      pixelRatio: 2.0,
      textScale: 1.0,
      compact: false,
    ),
  ]) {
    testWidgets(
      'captures every production Flutter admin section at ${profile.name}',
      (tester) async {
        tester.view.devicePixelRatio = profile.pixelRatio;
        tester.view.physicalSize = Size(
          profile.size.width * profile.pixelRatio,
          profile.size.height * profile.pixelRatio,
        );
        addTearDown(tester.view.reset);
        await loadUiuxVisualCaptureFonts();

        final api = AccessibleAdminApi();
        final state = AppState(api)..topology = api.current;
        addTearDown(state.dispose);
        final captureKey = ValueKey('uiux-admin-capture-${profile.name}');
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(profile.textScale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: captureKey,
              child: Scaffold(body: AdminScreen(state: state)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final roleLabel = find.descendant(
          of: find.byKey(const ValueKey('admin-member-role-filter')),
          matching: find.text(
            profile.compact && profile.textScale == 1 ? 'Все' : 'Все роли',
          ),
        );
        expect(roleLabel, findsOneWidget);
        final roleText = tester.widget<Text>(roleLabel);
        expect(
          roleText.style?.fontFamily ??
              DefaultTextStyle.of(tester.element(roleLabel)).style.fontFamily,
          GcTypography.fontFamily,
        );
        final statusLabel = find.descendant(
          of: find.byKey(const ValueKey('admin-member-status-filter')),
          matching: find.text(
            profile.compact && profile.textScale == 1
                ? 'Любой'
                : 'Любой статус',
          ),
        );
        expect(statusLabel, findsOneWidget);
        final statusText = tester.widget<Text>(statusLabel);
        expect(
          statusText.style?.fontFamily ??
              DefaultTextStyle.of(tester.element(statusLabel)).style.fontFamily,
          GcTypography.fontFamily,
        );
        if (profile.compact && profile.textScale > 1) {
          final titleText = find.descendant(
            of: find.byKey(const ValueKey('admin-screen-title')),
            matching: find.byType(RichText),
          );
          expect(
            tester.widget<RichText>(titleText).text.toPlainText(),
            'Админ-панель',
          );
          expect(
            tester.renderObject<RenderParagraph>(titleText).didExceedMaxLines,
            isFalse,
            reason: 'the compact admin heading is not clipped at 2× text',
          );
          expect(
            tester
                .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
                .getSemanticsData()
                .label,
            'Администрирование',
            reason: 'the full admin title remains available to assistive technology',
          );
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('admin-member-search')),
                )
                .decoration
                ?.hintText,
            'Поиск',
            reason: 'the large-text search hint uses concise, unclipped copy',
          );
        }

        for (final section in AdminSection.values) {
          final tab = find.byKey(ValueKey('admin-section-tab-${section.name}'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester
                    .getSemantics(tab)
                    .getSemanticsData()
                    .flagsCollection
                    .isSelected ==
                Tristate.isTrue,
            isTrue,
            reason: '${section.name} is the active admin tab',
          );
          expect(tester.takeException(), isNull, reason: section.name);
          if (section == AdminSection.members && profile.compact) {
            expect(find.text('Роль'), findsOneWidget);
            expect(find.textContaining('Роль: long-login-'), findsNothing);
          }
          if (section == AdminSection.guild && profile.textScale > 1) {
            final helper = find.text(
              'От 1 до 80 символов, без переводов строк.',
            );
            expect(helper, findsOneWidget);
            expect(
              tester.renderObject<RenderParagraph>(helper).didExceedMaxLines,
              isFalse,
              reason: 'guild name guidance wraps fully at 2× text',
            );
            final welcomeLabel = find.text('Приветствия');
            expect(welcomeLabel, findsOneWidget);
            expect(
              tester.widget<Text>(welcomeLabel).semanticsLabel,
              'Приветствия новых участников',
              reason: 'the concise large-text label retains its full accessible name',
            );
          }
          if (section == AdminSection.roles &&
              profile.compact &&
              profile.textScale > 1) {
            final heading = find.text('Роли и разрешения');
            final refresh = find.widgetWithText(TextButton, 'Обновить');
            expect(heading, findsOneWidget);
            expect(refresh, findsOneWidget);
            expect(
              tester.getRect(refresh).top,
              greaterThanOrEqualTo(tester.getRect(heading).bottom - 1),
              reason: 'the role refresh action must not overlap its heading',
            );
          }
          await captureUiuxBoundary(
            tester,
            find.byKey(captureKey),
            fileName:
                'flutter-admin-${section.name}-${profile.name}-${profile.size.width.toInt()}x${profile.size.height.toInt()}.png',
            pixelRatio: profile.pixelRatio,
          );
        }
      },
    );
  }
}
