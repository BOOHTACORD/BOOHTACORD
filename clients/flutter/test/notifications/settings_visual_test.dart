import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/features/notifications/settings/account_controls.dart';
import 'package:boohtacord_desktop/src/features/notifications/settings/device_controls.dart';

import '../uiux_2026/capture_support.dart';

void main() {
  for (final profile in [(393.0, 1.0), (393.0, 2.0), (1440.0, 1.0)]) {
    testWidgets(
      'notification controls preserve layout at ${profile.$1} scale ${profile.$2}',
      (tester) async {
        tester.view.physicalSize = Size(profile.$1, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadUiuxVisualCaptureFonts();
        const key = ValueKey('notification-controls');
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(profile.$1, 1100),
                textScaler: TextScaler.linear(profile.$2),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NotificationAccountControls(
                                settings: const {
                                  'enabled': false,
                                  'dm': {'mode': 'all', 'paused_until': null},
                                  'text': {
                                    'mode': 'mentions',
                                    'paused_until': null,
                                  },
                                },
                                busy: false,
                                operatorAvailable: false,
                                onEnabled: (_) {},
                                onMode: (_, _) {},
                                onPause: (_, _) {},
                              ),
                              NotificationDeviceControls(
                                ready: false,
                                busy: false,
                                status: 'Фоновая доставка недоступна в этой сборке или на этом сервере',
                                devices: const [
                                  {
                                    'id': 'synthetic',
                                    'generation': 1,
                                    'transport': 'web_push',
                                    'state': 'active',
                                  },
                                ],
                                onEnable: () async {},
                                onRevoke: (_) async {},
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Локальное включение не разрешает фоновую доставку. Перенос требует отдельного подтверждения.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final name =
            'notification-settings-${profile.$1.toInt()}-${profile.$2.toInt()}';
        await captureUiuxBoundary(
          tester,
          find.byKey(key),
          fileName: '$name-top.png',
          pixelRatio: 1,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureUiuxBoundary(
          tester,
          find.byKey(key),
          fileName: '$name-bottom.png',
          pixelRatio: 1,
        );
      },
    );
  }
}
