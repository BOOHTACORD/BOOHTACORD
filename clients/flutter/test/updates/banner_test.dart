import 'package:boohtacord_desktop/src/features/updates/banner.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long update summary stays compact at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const summary =
        'BOOHTACORD Windows 1.0.32: сочетания клавиш, уведомления голосовой '
        'сессии, настройки аудио и обновлённая админка.';
    final updates = UpdateController.disabled()
      ..visible = true
      ..policy = const UpdatePolicy(
        target: UpdateTarget(
          releaseId: 'windows-direct-stable-r46',
          releaseOrder: 46,
          arches: ['x64'],
          version: '1.0.32',
          nativeBuild: '46',
          priority: 'normal',
          summary: summary,
          releaseNotesUrl: 'https://github.com/Egkurilov/BOOHTACORD/releases',
          actionKind: 'open_download_page',
          actionUrl: 'https://github.com/Egkurilov/BOOHTACORD/releases',
        ),
      );
    addTearDown(updates.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 900),
            textScaler: TextScaler.linear(2.5),
          ),
          child: Column(
            children: [
              ClientUpdateBanner(updates: updates, appBusy: false),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );

    final summaryText = tester.widget<Text>(find.text(summary));
    final rendered = tester.widget<RichText>(
      find.descendant(of: find.text(summary), matching: find.byType(RichText)),
    );
    expect(rendered.text.style?.fontSize, lessThan(24));
    expect(summaryText.maxLines, 2);
    expect(summaryText.style?.decoration, TextDecoration.none);
    expect(
      tester.getSize(find.byKey(const ValueKey('client-update-banner'))).height,
      lessThan(220),
    );
    expect(tester.takeException(), isNull);
  });
}
