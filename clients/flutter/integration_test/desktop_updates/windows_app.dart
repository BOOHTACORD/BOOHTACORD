// Release-mode integration driver around the unchanged shipping entrypoint.
// It never acknowledges bootstrap, writes recovery outcomes or simulates apply.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/coordinator.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';

import 'native_app.dart' as native;

Future<void> until(
  bool Function() predicate,
  String reason, {
  int seconds = 45,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) throw StateError(reason);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

String digest(String value) => sha256.convert(utf8.encode(value)).toString();
void require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

class Journey {
  Journey(this.output);
  final Directory output;
  final driver = LiveWidgetController(WidgetsBinding.instance);
  BoohtacordApp get app =>
      driver.widget<BoohtacordApp>(find.byType(BoohtacordApp));
  AppState get state => app.state;
  DesktopUpdateCoordinator get desktop => app.updates.desktop!;
  Finder get composer => find.descendant(
    of: find.byKey(const ValueKey('text-composer-wrap')),
    matching: find.byType(EditableText),
  );

  Future<void> tap(Finder finder) async {
    await until(() => finder.evaluate().isNotEmpty, 'control_missing');
    await driver.tap(finder.first);
    await driver.pump(const Duration(milliseconds: 120));
  }

  Future<void> edit(String value) async {
    await tap(composer);
    driver
        .state<EditableTextState>(composer)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
    await driver.pump(const Duration(milliseconds: 100));
  }

  Map<String, num> anchor() {
    final viewport = driver.getRect(
      find.byKey(const ValueKey('text-channel-messages')),
    );
    final visible = <({int ordinal, double top})>[];
    for (final element in find.byType(Text).evaluate()) {
      final text = element.widget as Text;
      final match = RegExp(r'^Update history row (\d+)$')
          .firstMatch(text.data ?? '');
      final box = element.findRenderObject();
      if (match == null || box is! RenderBox || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.overlaps(viewport)) {
        visible.add((
          ordinal: int.parse(match[1]!),
          top: rect.top - viewport.top,
        ));
      }
    }
    visible.sort((a, b) => a.top.compareTo(b.top));
    require(visible.isNotEmpty, 'history_anchor_missing');
    return {'ordinal': visible.first.ordinal, 'top': visible.first.top};
  }

  Future<void> capture(String name) async {
    await driver.pump(const Duration(milliseconds: 100));
    final boundary = driver.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    require(data != null, 'capture_failed');
    await File(path.join(output.path, '$name.png'))
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  }

  Future<Map<String, dynamic>> snapshot() async {
    final window = await windowManager.getBounds();
    return {
      'account_digest': digest(state.user!.accountId),
      'origin_digest': digest(state.serverUrl),
      'channel_digest': digest(state.selectedChannel!.id),
      'draft_digest': digest(
        driver.widget<EditableText>(composer).controller.text,
      ),
      'anchor': anchor(),
      'window': [window.left, window.top, window.width, window.height],
      'muted': state.microphoneMuted,
      'deafened': state.deafened,
    };
  }

  Future<void> before() async {
    await windowManager.setBounds(const Rect.fromLTWH(40, 40, 1200, 800));
    await tap(find.text('Update VOICE'));
    await tap(find.text('Подключиться без микрофона'));
    await until(
      () =>
          state.voicePhase == VoicePhase.connected ||
          state.voicePhase == VoicePhase.listener,
      'voice_not_connected',
    );
    require(state.microphoneMuted, 'microphone_not_muted');
    if (!state.deafened) await tap(find.byTooltip('Выключить удалённый звук'));
    require(state.deafened, 'incoming_audio_not_muted');
    await tap(find.text('Update TEXT'));
    await until(() => state.messages.length >= 50, 'history_not_loaded');
    await edit('Owned updater draft before download');
    await tap(find.widgetWithText(FilledButton, 'Обновить'));
    await until(
      () => desktop.phase == DesktopUpdatePhase.downloading,
      'download_not_observed',
    );
    await edit('Owned updater draft changed during actual download');
    await until(
      () =>
          desktop.phase == DesktopUpdatePhase.readyToRestart ||
          desktop.phase == DesktopUpdatePhase.failed,
      'staging_timeout',
      seconds: 180,
    );
    require(
      desktop.phase == DesktopUpdatePhase.readyToRestart,
      'staging_failed',
    );
    require(
      state.voiceChannel != null && state.microphoneMuted && state.deafened,
      'voice_interrupted_by_download',
    );
    await edit(
      'Owned updater draft changed during actual download and after Ready',
    );
    await driver.timedDrag(
      find.byKey(const ValueKey('text-channel-messages')),
      const Offset(0, 1200),
      const Duration(milliseconds: 500),
    );
    await driver.pump(const Duration(milliseconds: 700));
    final expected = await snapshot();
    require(
      (expected['anchor'] as Map)['ordinal'] < 60,
      'history_not_scrolled',
    );
    await File(path.join(output.path, 'expected.json'))
        .writeAsString(jsonEncode(expected), flush: true);
    await capture('before-installed-update');
    await tap(find.widgetWithText(FilledButton, 'Перезапустить'));
    await tap(find.text('Продолжить работу'));
    require(
      desktop.phase == DesktopUpdatePhase.readyToRestart &&
          state.voiceChannel != null,
      'decline_restart_interrupted_work',
    );
    await tap(find.widgetWithText(FilledButton, 'Перезапустить'));
    await tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Перезапустить'),
      ),
    );
    // Native apply terminates this process only after actual user-consent actions.
  }

  Future<void> after() async {
    await until(
      () => desktop.phase == DesktopUpdatePhase.completed,
      'native_bootstrap_not_completed',
    );
    await driver.pump(const Duration(seconds: 2));
    final expected = jsonDecode(
      await File(path.join(output.path, 'expected.json')).readAsString(),
    ) as Map;
    final actual = await snapshot();
    for (final key in [
      'account_digest',
      'origin_digest',
      'channel_digest',
      'draft_digest',
      'muted',
      'deafened',
    ]) {
      require(actual[key] == expected[key], '${key}_not_restored');
    }
    final beforeAnchor = expected['anchor'] as Map,
        afterAnchor = actual['anchor'] as Map;
    require(
      beforeAnchor['ordinal'] == afterAnchor['ordinal'] &&
          ((beforeAnchor['top'] as num) - (afterAnchor['top'] as num)).abs() <
              2,
      'scroll_not_restored',
    );
    for (var index = 0; index < 4; index++) {
      require(
        ((actual['window'] as List)[index] -
                    (expected['window'] as List)[index])
                .abs() <
            2,
        'window_not_restored',
      );
    }
    require(
      state.voiceChannel == null &&
          state.screenSharePhase != ScreenSharePhase.sharing,
      'media_restarted_without_consent',
    );
    await capture('after-installed-update');
    await tap(find.text('Update VOICE'));
    await tap(find.text('Подключиться без микрофона'));
    await until(
      () =>
          state.voicePhase == VoicePhase.connected ||
          state.voicePhase == VoicePhase.listener,
      'rejoin_failed',
    );
    require(
      state.microphoneMuted && state.deafened,
      'audio_intent_lost_on_rejoin',
    );
    await capture('after-explicit-voice-rejoin');
    await File(path.join(output.path, 'result.json')).writeAsString(
      jsonEncode({
        'status': 'PASS',
        'installed_build': '79',
        'native_apply': true,
        'account': true,
        'origin': true,
        'channel': true,
        'late_draft': true,
        'scroll': true,
        'window': true,
        'mute_deafen': true,
        'explicit_voice_rejoin': true,
      }),
      flush: true,
    );
  }
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
  try {
    await native.main();
    final identity = await NativeUpdateIdentity.load();
    final journey = Journey(output);
    await until(
      () =>
          find.byType(BoohtacordApp).evaluate().isNotEmpty &&
          journey.state.phase == AppPhase.ready,
      'workspace_not_ready',
    );
    require(
      identity.local.nativeBuild == identity.local.installedBuild,
      'compiled_native_build_mismatch',
    );
    if (identity.local.installedBuild == '78') {
      await journey.before();
    } else {
      require(identity.local.installedBuild == '79', 'unexpected_native_build');
      await journey.after();
    }
  } catch (error) {
    // Raw exceptions may contain paths or application data. Retain only this
    // fixed failure result; private fixture state is never uploaded by CI.
    final reason =
        error is StateError && RegExp(r'^[a-z_]{1,64}$').hasMatch(error.message)
        ? error.message
        : 'native_journey';
    await File(path.join(output.path, 'failure.json')).writeAsString(
      jsonEncode({'status': 'FAIL', 'reason': reason}),
      flush: true,
    );
  }
}
