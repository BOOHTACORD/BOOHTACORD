import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/admin/telemetry/model.dart';
import 'package:boohtacord_desktop/src/features/admin/telemetry/panel.dart';

import 'controller_test.dart' show fixture;

class PanelApi extends ApiClient {
  int writes = 0;
  @override
  Future<TelemetrySettings> readTelemetrySettings() async =>
      TelemetrySettings.fromJson(fixture());
  @override
  Future<TelemetrySettings> updateTelemetrySettings(
    String mode,
    String endpoint,
    bool confirmed,
  ) async {
    expect(mode, 'central');
    expect(endpoint, 'https://center.example');
    expect(confirmed, isTrue);
    writes++;
    return TelemetrySettings.fromJson({
      ...fixture(),
      'mode': 'central',
      'state': 'never_connected',
    });
  }
}

void main() {
  testWidgets(
    'compact large text keeps opt-in reachable, refresh clears consent, opening never writes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PanelApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: AdminTelemetryPanel(api: api),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      Future<void> show(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
        await tester.pumpAndSettle();
      }

      final consent = find.byType(Checkbox);
      await show(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      final refresh = find.text('Обновить состояние');
      await show(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(consent).value, isFalse);
      final endpoint = find.byType(TextField);
      await show(endpoint);
      await tester.enterText(endpoint, 'http://center.example');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await show(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await show(endpoint);
      await tester.enterText(endpoint, 'https://center.example');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final connect = find.text('Подключить центр');
      await show(connect);
      await tester.tap(connect);
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(find.textContaining('Нет подтверждения приёма'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
