// Release-mode Windows acceptance around the shipping entrypoint and real SFU.
// Only synthetic accounts on the disposable CI host are permitted.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/window_bounds.dart';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/dialog.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/footer.dart';

import 'screen_setup_controls.dart';
import 'screen_setup_launchers.dart';
import 'desktop_updates/native_app.dart' as native;
import 'desktop_updates/windows_app.dart' show Journey, until, require;

// Capture the complete rendered view, including the modal overlay. The first
// route's RepaintBoundary would omit a dialog displayed above that route.
class ScreenSetupJourney extends Journey {
  ScreenSetupJourney(super.output);

  void visibleActions() {
    final view = WidgetsBinding.instance.renderViews.single.flutterView;
    final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    final surface = driver.getRect(
      find
          .ancestor(
            of: find.byType(SetupFooter),
            matching: find.byType(Material),
          )
          .first,
    );
    final bounds = viewport.deflate(20).intersect(surface);
    for (final entry in {
      'cancel': find.widgetWithText(TextButton, 'Отмена'),
      'start': find.byKey(const ValueKey('start-screen-share')),
      'close': find.byTooltip('Закрыть'),
    }.entries) {
      final control = screenSetupControl(entry.value);
      require(control.evaluate().length == 1, '${entry.key}_action_missing');
      final rect = driver.getRect(control);
      require(
        bounds.contains(rect.topLeft) &&
            bounds.contains(rect.bottomRight) &&
            control.hitTestable().evaluate().length == 1,
        'action_clipped',
      );
    }
  }

  @override
  Future<void> capture(String name) async {
    await driver.pump(const Duration(milliseconds: 100));
    final view = WidgetsBinding.instance.renderViews.single;
    // QA-only read of the painted root; the public route-boundary capture
    // omits modal overlay entries in release mode.
    // ignore: invalid_use_of_protected_member
    final layer = view.layer;
    require(layer is OffsetLayer, 'view_layer_missing');
    final image = await (layer as OffsetLayer).toImage(
      Offset.zero & view.flutterView.physicalSize,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      require(data != null, 'capture_failed');
      await File(path.join(output.path, '$name.png'))
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }
}

// Use the Windows input queue, not WidgetTester.sendKeyEvent. Refuse to send
// keys unless this exact test process owns the foreground window.
Future<void> osKey(VIRTUAL_KEY key, {bool shift = false}) async {
  await windowManager.focus();
  final owner = calloc<Uint32>();
  final input = calloc<INPUT>();
  try {
    GetWindowThreadProcessId(GetForegroundWindow(), owner);
    require(owner.value == pid, 'foreign_foreground_window');
    void send(VIRTUAL_KEY value, bool up) {
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = value;
      input.ref.ki.dwFlags = KEYBD_EVENT_FLAGS(up ? 2 : 0);
      require(
        SendInput(1, input, sizeOf<INPUT>()).value == 1,
        'os_key_rejected',
      );
    }

    if (shift) send(VK_SHIFT, false);
    try {
      send(key, false);
      send(key, true);
    } finally {
      if (shift) send(VK_SHIFT, true);
    }
  } finally {
    calloc.free(owner);
    calloc.free(input);
  }
  await Future<void>.delayed(const Duration(milliseconds: 350));
}

Future<void> main() async {
  require(Platform.isWindows, 'windows_required');
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final config = jsonDecode(
    await File(path.join(support.path, 'issue337-acceptance-private.json'))
        .readAsString(),
  ) as Map;
  final output = Directory(config['windows_acceptance'] as String);
  final temporary = Platform.environment['RUNNER_TEMP'];
  require(
    temporary != null &&
        path.isWithin(temporary, output.path) &&
        path.basename(output.path) == 'driver' &&
        RegExp(r'^qa337-[a-f0-9]{16}$')
            .hasMatch(path.basename(output.parent.path)),
    'owned_fixture_required',
  );
  output.createSync(recursive: true);
  Journey? journey;
  try {
    await native.main();
    final qa = ScreenSetupJourney(output);
    journey = qa;
    await until(
      () =>
          find.byType(BoohtacordApp).evaluate().isNotEmpty &&
          qa.state.phase == AppPhase.ready,
      'workspace_not_ready',
    );
    final displays = await screenRetriever.getAllDisplays();
    require(displays.isNotEmpty, 'fixture_display_missing');
    await windowManager.setBounds(
      visibleWindowBounds(const Rect.fromLTWH(40, 40, 1200, 800), [
        for (final display in displays)
          (display.visiblePosition ?? Offset.zero) &
              (display.visibleSize ?? display.size),
      ]),
    );
    await qa.openVoiceWithoutJoining('Update VOICE');
    await qa.joinListener();
    await until(
      () =>
          qa.state.voicePhase == VoicePhase.listener ||
          qa.state.voicePhase == VoicePhase.connected,
      'voice_not_connected',
    );
    final state = qa.state, room = qa.state.voice.room;
    final lease = state.voice.leaseId;
    final muted = state.microphoneMuted, deafened = state.deafened;
    require(room != null && lease != null && muted, 'listener_missing');
    final phase = state.voicePhase;
    final selectedQuality = state.screenShareSelectedQuality;
    final rows = <Map<String, Object>>[];
    for (final dock in [false, true]) {
      for (final traverse in [false, true]) {
        qa.step =
            '${dock ? 'dock' : 'header'}_${traverse ? 'traversed' : 'initial'}_launcher';
        final trigger = await waitForScreenSetupLauncher(qa.driver, dock: dock);
        final icon = find
            .descendant(
              of: trigger,
              matching: find.byIcon(Icons.screen_share_outlined),
            )
            .first;
        final focus = Focus.of(qa.driver.element(icon));
        focus.requestFocus();
        await qa.driver.pump(const Duration(milliseconds: 100));
        await osKey(VK_RETURN);
        await until(
          () => find.byType(ScreenShareSetupDialog).evaluate().isNotEmpty,
          'dialog_not_open',
        );
        qa.visibleActions();
        if (!traverse) await qa.capture('${dock ? 'dock' : 'header'}-open');
        if (traverse) {
          // Exercise the scrollable quality section, including its expansion.
          final advanced = screenSetupControl(
            find.byKey(const ValueKey('screen-share-advanced-quality')),
          );
          await qa.driver.ensureVisible(advanced);
          await qa.driver.tap(advanced);
          await qa.driver.pump();
          await qa.driver.pump(const Duration(milliseconds: 500));
          for (final label in ['720p', '30 FPS', 'Текст']) {
            final option = screenSetupControl(find.text(label));
            await qa.driver.ensureVisible(option);
            await qa.driver.pump(const Duration(milliseconds: 200));
            require(
              option.hitTestable().evaluate().length == 1,
              'quality_unreachable',
            );
            await qa.driver.tap(option);
            await qa.driver.pump(const Duration(milliseconds: 200));
          }
          qa.visibleActions();
          await qa.capture('${dock ? 'dock' : 'header'}-footer');
          // Prove the footer participates in actual Windows keyboard traversal.
          final cancelText = find.descendant(
            of: screenSetupControl(find.widgetWithText(TextButton, 'Отмена')),
            matching: find.byType(Text),
          );
          final cancelFocus = Focus.of(qa.driver.element(cancelText));
          var reachedCancel = false;
          for (var tab = 0; tab < 40; tab++) {
            await osKey(VK_TAB);
            if (cancelFocus.hasFocus) {
              reachedCancel = true;
              break;
            }
          }
          require(reachedCancel, 'cancel_keyboard_unreachable');
          await osKey(VK_TAB, shift: true);
          await osKey(VK_TAB);
          require(cancelFocus.hasFocus, 'cancel_reverse_traversal_failed');
        }
        await osKey(VK_ESCAPE);
        await until(
          () => find.byType(ScreenShareSetupDialog).evaluate().isEmpty,
          'escape_did_not_close',
          seconds: 5,
        );
        await qa.driver.pump(const Duration(milliseconds: 500));
        require(focus.hasFocus, 'launcher_focus_not_restored');
        require(
          identical(state.voice.room, room) &&
              state.voice.leaseId == lease &&
              state.voicePhase == phase &&
              state.microphoneMuted == muted &&
              state.deafened == deafened,
          'voice_state_changed',
        );
        require(
          state.screenSharePhase == ScreenSharePhase.idle &&
              state.screenShareSelectedQuality == selectedQuality &&
              !room!.localParticipant!.isScreenShareEnabled(),
          'capture_started',
        );
        final name =
            '${dock ? 'dock' : 'header'}-${traverse ? 'traversed' : 'initial'}';
        await qa.capture(name);
        rows.add({
          'case': name,
          'escape': true,
          'focus_returned': true,
          'same_connected_room_and_lease': true,
          'mute_deafen_preserved': true,
          'no_publication': true,
          'footer_visible': true,
          if (traverse) 'quality_reachable': true,
          if (traverse) 'cancel_keyboard_reachable': true,
        });
      }
    }
    // Observe past the source-inventory refresh interval; cancellation must
    // not start capture or disturb the established voice session later.
    await Future<void>.delayed(const Duration(seconds: 5));
    require(
      identical(state.voice.room, room) &&
          state.voicePhase == phase &&
          state.screenSharePhase == ScreenSharePhase.idle &&
          !room!.localParticipant!.isScreenShareEnabled(),
      'late_cancel_effect',
    );
    await File(path.join(output.path, 'result.json')).writeAsString(
      jsonEncode({
        'status': 'PASS',
        'os': Platform.operatingSystemVersion,
        'input': 'Win32 SendInput with exact foreground PID guard',
        'cases': rows,
        'scope': 'Actual release Windows GUI, real API/PostgreSQL/LiveKit listener. No acoustic/media quality claim.',
      }),
    );
  } catch (error) {
    if (journey != null) {
      try {
        await journey.capture('failure');
      } catch (_) {}
    }
    await File(path.join(output.path, 'failure.json')).writeAsString(
      jsonEncode({
        'status': 'FAIL',
        'step': journey?.step ?? 'startup',
        'reason':
            error is StateError &&
                RegExp(r'^[a-z_]+$').hasMatch(error.message.toString())
            ? error.message
            : 'uncategorized',
      }),
    );
  }
}
