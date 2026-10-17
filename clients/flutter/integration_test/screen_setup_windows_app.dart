// Release-mode Windows acceptance around the shipping entrypoint and real SFU.
// Only synthetic accounts on the disposable CI host are permitted.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
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
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_dock_button/component.dart';

import 'desktop_updates/native_app.dart' as native;
import 'desktop_updates/windows_app.dart' show Journey, until, require;

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
    final qa = Journey(output);
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
        final launcher = find
            .ancestor(
              of: find.byTooltip('Начать демонстрацию экрана'),
              matching: dock
                  ? find.byType(WorkspaceVoiceDockButton)
                  : find.byType(IconButton),
            )
            .hitTestable();
        // The dock tooltip is inside its custom button; select by ancestry.
        final trigger = dock
            ? find
                  .descendant(
                    of: find.byType(WorkspaceVoiceDockButton),
                    matching: find.byTooltip('Начать демонстрацию экрана'),
                  )
                  .hitTestable()
            : launcher;
        require(trigger.evaluate().length == 1, 'launcher_not_unique');
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
        if (!traverse) await qa.capture('${dock ? 'dock' : 'header'}-open');
        if (traverse) {
          await osKey(VK_TAB);
          await osKey(VK_TAB, shift: true);
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
