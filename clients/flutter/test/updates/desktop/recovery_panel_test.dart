import 'dart:io';

import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/coordinator.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/native_adapter.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/panel.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/staging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class NoNativeCalls extends Fake implements DesktopNativeUpdater {}

void main() {
  for (final manualRecovery in [true, false]) {
    testWidgets(
      'uncertain ${manualRecovery ? 'recovery' : 'apply'} offers repair without claiming a preserved binary',
      (tester) async {
        final root = Directory.systemTemp;
        const identity = NativeUpdateIdentity(
          LocalUpdateIdentity(releaseId: 'win1', releaseOrder: 1),
          UpdateSelector.windows('x64'),
          UpdateEnvironment(osVersion: '10.0', arch: 'x64'),
        );
        final desktop = DesktopUpdateCoordinator(
          trust: ArtifactTrust({}),
          local: identity.local,
          selector: identity.selector,
          environment: identity.environment,
          store: DesktopUpdateStore(root),
          native: NoNativeCalls(),
          currentScope: () => 'synthetic',
          checkpoint: (_, _) async {},
          shutdown: () async {},
        );
        final updates = UpdateController(
          api: UpdateApi(baseUrl: () => 'https://invalid.local'),
          identity: identity,
          desktop: desktop,
        );
        addTearDown(updates.dispose);
        if (manualRecovery) {
          desktop.recovered(rolledBack: false);
        } else {
          desktop.nativeFailed();
        }
        await tester.pumpWidget(
          MaterialApp(
            home: DesktopUpdatePanel(
              updates: updates,
              appBusy: false,
              inSettings: true,
            ),
          ),
        );
        final rendered = tester.widget<RichText>(
          find
              .descendant(
                of: find.byKey(const ValueKey('desktop-update-transaction')),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(rendered.text.style?.fontSize, lessThan(24));
        expect(
          rendered.text.style?.decoration,
          isNot(TextDecoration.underline),
        );
        expect(find.textContaining('Текущая версия сохранена'), findsNothing);
        expect(find.text('Открыть официальные выпуски'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
