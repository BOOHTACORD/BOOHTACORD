import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/notifications/settings/account_controls.dart';
import 'package:boohtacord_desktop/src/features/notifications/settings/device_controls.dart';

void main() {
  testWidgets(
    'account opt-in does not request device permission and operator off is visible',
    (tester) async {
      var account = false;
      var device = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NotificationAccountControls(
                    settings: {
                      'enabled': false,
                      'dm': {'mode': 'all', 'paused_until': null},
                      'text': {'mode': 'mentions', 'paused_until': null},
                    },
                    busy: false,
                    operatorAvailable: false,
                    onEnabled: (v) => account = v,
                    onMode: (_, _) {},
                    onPause: (_, _) {},
                  ),
                  NotificationDeviceControls(
                    ready: false,
                    busy: false,
                    status: 'Фоновая доставка недоступна в этой сборке',
                    devices: const [],
                    onEnable: () async {
                      device++;
                    },
                    onRevoke: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Оператор отключил доставку уведомлений.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('notification-account-enabled')),
      );
      await tester.pump();
      expect(account, isTrue);
      expect(device, 0);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Включить на этом устройстве'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
