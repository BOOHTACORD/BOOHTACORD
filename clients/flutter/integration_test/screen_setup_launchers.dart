import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_dock_button/component.dart';

Finder screenSetupLauncher({required bool dock}) =>
    (dock
            ? find.descendant(
                of: find.byType(WorkspaceVoiceDockButton),
                matching: find.byTooltip('Начать демонстрацию экрана'),
              )
            : find.ancestor(
                of: find.byTooltip('Начать демонстрацию экрана'),
                matching: find.byType(IconButton),
              ))
        .hitTestable();

// The SFU state may become connected before Flutter paints its controls.
// Observe frames in this same connection attempt; duplicates still fail.
Future<Finder> waitForScreenSetupLauncher(
  WidgetController driver, {
  required bool dock,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  final trigger = screenSetupLauncher(dock: dock);
  do {
    await driver.pump(const Duration(milliseconds: 50));
    final count = trigger.evaluate().length;
    if (count > 1) throw StateError('launcher_not_unique');
    if (count == 1) return trigger;
  } while (DateTime.now().isBefore(deadline));
  throw StateError('launcher_not_visible');
}
