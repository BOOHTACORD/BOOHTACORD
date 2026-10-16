// Release-mode integration driver around the unchanged shipping entrypoint.
// It never acknowledges bootstrap, writes recovery outcomes or simulates apply.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/widgets/formatted_message_body.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/coordinator.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/failure.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/window_bounds.dart';

import 'native_app.dart' as native;
import 'voice_diagnostics.dart';

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
  Journey(this.output, {WidgetController? controller})
    : driver = controller ?? LiveWidgetController(WidgetsBinding.instance);
  final Directory output;
  String step = 'startup';
  Map<String, num>? restorationExpectedAnchor, restorationObservedAnchor;
  final WidgetController driver;
  BoohtacordApp get app =>
      driver.widget<BoohtacordApp>(find.byType(BoohtacordApp));
  AppState get state => app.state;
  DesktopUpdateCoordinator get desktop => app.updates.desktop!;
  Finder get composer => find.descendant(
    of: find.byKey(const ValueKey('text-composer-wrap')),
    matching: find.byType(EditableText),
  );

  Future<void> tap(Finder finder, {required String at}) async {
    step = at;
    final visible = finder.hitTestable();
    await until(() => visible.evaluate().isNotEmpty, 'control_missing');
    await driver.tap(visible.first);
    await driver.pump();
    await driver.pump(const Duration(milliseconds: 350));
  }

  Future<void> openChannel(String label, {required String at}) async {
    final channel = find.text(label);
    if (channel.hitTestable().evaluate().isEmpty) {
      await tap(find.byTooltip('Открыть навигацию'), at: 'navigation_open');
    }
    await tap(channel, at: at);
  }

  Future<void> openVoiceWithoutJoining(String label) async {
    final launcher = find.byKey(const ValueKey('navigation-search'));
    if (launcher.hitTestable().evaluate().isEmpty) {
      await tap(find.byTooltip('Открыть навигацию'), at: 'navigation_open');
    }
    await tap(launcher, at: 'search_open');
    await tap(find.byTooltip('Каналы и люди'), at: 'quick_jump_open');
    // Compact drawer rows intentionally autojoin with the normal microphone
    // mode. Quick jump is the public UI path for opening a room without joining.
    await tap(
      find.descendant(
        of: find.byKey(const ValueKey('guild-quick-jump-results')),
        matching: find.text(label),
      ),
      at: 'voice_open',
    );
  }

  Future<void> joinListener() async {
    final button = find.widgetWithText(
      OutlinedButton,
      'Подключиться без микрофона',
    );
    step = 'voice_listener';
    await until(
      () =>
          button.hitTestable().evaluate().isNotEmpty &&
          driver.widget<OutlinedButton>(button).onPressed != null,
      'listener_control_disabled',
    );
    await tap(button, at: 'voice_listener');
  }

  Future<void> edit(String value) async {
    await tap(composer, at: 'composer');
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

  Map<String, num> anchor({int? referenceOrdinal}) {
    final viewport = driver.getRect(
      find.byKey(const ValueKey('text-channel-messages')),
    );
    final visible = <({int ordinal, double top})>[];
    // A reference row can become fractionally clipped at the viewport edge.
    // Read its actual cached geometry; the unchanged offset tolerance below
    // still rejects scrolling to a different position.
    for (final element
        in find
            .byType(
              FormattedMessageBody,
              skipOffstage: referenceOrdinal == null,
            )
            .evaluate()) {
      final body = element.widget as FormattedMessageBody;
      final match = RegExp(r'^Update history row (\d+)$').firstMatch(body.body);
      final box = element.findRenderObject();
      if (match == null || box is! RenderBox || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final ordinal = int.parse(match[1]!);
      if (referenceOrdinal == null
          ? rect.overlaps(viewport)
          : ordinal == referenceOrdinal) {
        visible.add((ordinal: ordinal, top: rect.top - viewport.top));
      }
    }
    visible.sort((a, b) => a.top.compareTo(b.top));
    require(visible.isNotEmpty, 'history_anchor_missing');
    return {'ordinal': visible.first.ordinal, 'top': visible.first.top};
  }

  Future<void> waitForRestoredAnchor(
    Map expected, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    restorationExpectedAnchor = {
      'ordinal': expected['ordinal'] as num,
      'top': expected['top'] as num,
    };
    final deadline = DateTime.now().add(timeout);
    var stable = 0;
    do {
      await driver.pump(const Duration(milliseconds: 50));
      try {
        final observed = anchor(referenceOrdinal: expected['ordinal'] as int);
        restorationObservedAnchor = observed;
        final matches =
            observed['ordinal'] == expected['ordinal'] &&
            (observed['top']! - (expected['top'] as num)).abs() < 2;
        stable = matches ? stable + 1 : 0;
        if (stable >= 2) return;
      } on StateError {
        stable = 0; // The lazily rendered reference message is not mounted yet.
      }
    } while (DateTime.now().isBefore(deadline));
    throw StateError('scroll_not_restored');
  }

  Future<void> waitForIdleHistory({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var stable = 0;
    do {
      await driver.pump(const Duration(milliseconds: 50));
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('text-channel-messages')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = driver.state<ScrollableState>(scrollable).position;
      stable = position.isScrollingNotifier.value ? 0 : stable + 1;
      if (stable >= 2) return;
    } while (DateTime.now().isBefore(deadline));
    throw StateError('history_not_idle');
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

  Future<Map<String, dynamic>> snapshot({int? referenceOrdinal}) async {
    final window = await windowManager.getBounds();
    return {
      'account_digest': digest(state.user!.accountId),
      'origin_digest': digest(state.serverUrl),
      'channel_digest': digest(state.selectedChannel!.id),
      'draft_digest': digest(
        driver.widget<EditableText>(composer).controller.text,
      ),
      'anchor': anchor(referenceOrdinal: referenceOrdinal),
      'window': [window.left, window.top, window.width, window.height],
      'muted': state.microphoneMuted,
      'deafened': state.deafened,
    };
  }

  Future<void> before() async {
    final displays = await screenRetriever.getAllDisplays();
    require(displays.isNotEmpty, 'fixture_display_missing');
    final frames = [
      for (final display in displays)
        (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size),
    ];
    // The runner can have a smaller desktop than a developer's monitor.
    // Start within its work area so the legitimate restore clamp is a no-op.
    await windowManager.setBounds(
      visibleWindowBounds(const Rect.fromLTWH(40, 40, 1200, 800), frames),
    );
    await openVoiceWithoutJoining('Update VOICE');
    await joinListener();
    await until(
      () =>
          state.voicePhase == VoicePhase.connected ||
          state.voicePhase == VoicePhase.listener,
      'voice_not_connected',
    );
    require(state.microphoneMuted, 'microphone_not_muted');
    if (!state.deafened) {
      await tap(find.byTooltip('Выключить удалённый звук'), at: 'deafen');
    }
    require(state.deafened, 'incoming_audio_not_muted');
    await openChannel('Update TEXT', at: 'text_open');
    await until(() => state.messages.length >= 50, 'history_not_loaded');
    await edit('Owned updater draft before download');
    await tap(find.widgetWithText(FilledButton, 'Обновить'), at: 'download');
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
    step = 'history_position';
    await driver.timedDrag(
      find.byKey(const ValueKey('text-channel-messages')),
      const Offset(0, 1200),
      const Duration(milliseconds: 500),
    );
    await waitForIdleHistory();
    await tap(
      find.widgetWithText(FilledButton, 'Перезапустить'),
      at: 'restart_open',
    );
    await tap(find.text('Продолжить работу'), at: 'restart_decline');
    await until(
      () => find.byType(AlertDialog).evaluate().isEmpty,
      'decline_dialog_not_closed',
    );
    require(
      desktop.phase == DesktopUpdatePhase.readyToRestart &&
          state.voiceChannel != null,
      'decline_restart_interrupted_work',
    );
    // Snapshot the settled current UI immediately before the final consent.
    // A timed drag can still be ballistic after an arbitrary 700 ms delay.
    await waitForIdleHistory();
    final expected = await snapshot();
    require(
      (expected['anchor'] as Map)['ordinal'] < 60,
      'history_not_scrolled',
    );
    await File(path.join(output.path, 'expected.json'))
        .writeAsString(jsonEncode(expected), flush: true);
    await capture('before-installed-update');
    await tap(
      find.widgetWithText(FilledButton, 'Перезапустить'),
      at: 'restart_open',
    );
    await tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Перезапустить'),
      ),
      at: 'restart_consent',
    );
    step = 'native_apply';
    // A real successful apply exits this process. Report native rejection here
    // rather than continuing a new scripted action or waiting without context.
    await until(
      () =>
          desktop.phase == DesktopUpdatePhase.failed ||
          desktop.phase == DesktopUpdatePhase.rolledBack,
      'native_apply_did_not_exit',
      seconds: 60,
    );
    throw StateError('native_apply_rejected');
  }

  Future<void> after() async {
    await until(
      () => desktop.phase == DesktopUpdatePhase.completed,
      'native_bootstrap_not_completed',
    );
    step = 'restored_state';
    await driver.pump(const Duration(seconds: 2));
    final expected = jsonDecode(
      await File(path.join(output.path, 'expected.json')).readAsString(),
    ) as Map;
    final beforeAnchor = expected['anchor'] as Map;
    await waitForRestoredAnchor(beforeAnchor);
    final actual = await snapshot(
      referenceOrdinal: beforeAnchor['ordinal'] as int,
    );
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
    final afterAnchor = actual['anchor'] as Map;
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
    await openVoiceWithoutJoining('Update VOICE');
    await joinListener();
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
  Journey? journey;
  String? installedBuild;
  final voiceDiagnostics = AcceptanceVoiceDiagnostics();
  Timer? statsObservation;
  var readingStats = false;
  final sdkObservation = Logger('livekit').onRecord.listen((record) {
    voiceDiagnostics.observe(record.loggerName, record.message);
  });
  try {
    await native.main();
    final identity = await NativeUpdateIdentity.load();
    installedBuild = identity.local.installedBuild;
    final activeJourney = Journey(output);
    journey = activeJourney;
    statsObservation = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (readingStats || find.byType(BoohtacordApp).evaluate().isEmpty) return;
      final voice = activeJourney.state.voice;
      final room = voice.pendingRoom ?? voice.room;
      if (room == null) return;
      readingStats = true;
      try {
        voiceDiagnostics.observeStats(await room.getPeerConnectionStats());
      } catch (_) {
        // Admission can dispose the actual room while a stats read is pending.
      } finally {
        readingStats = false;
      }
    });
    await until(
      () =>
          find.byType(BoohtacordApp).evaluate().isNotEmpty &&
          activeJourney.state.phase == AppPhase.ready,
      'workspace_not_ready',
    );
    require(
      ![
        DesktopUpdatePhase.failed,
        DesktopUpdatePhase.rolledBack,
      ].contains(activeJourney.desktop.phase),
      'startup_update_rejected',
    );
    require(
      identity.local.nativeBuild == identity.local.installedBuild,
      'compiled_native_build_mismatch',
    );
    if (identity.local.installedBuild == '78') {
      await activeJourney.before();
    } else {
      require(identity.local.installedBuild == '79', 'unexpected_native_build');
      await activeJourney.after();
    }
  } catch (error) {
    // Raw exceptions may contain paths or application data. Retain only this
    // fixed failure result; private fixture state is never uploaded by CI.
    final reason =
        error is StateError && RegExp(r'^[a-z_]{1,64}$').hasMatch(error.message)
        ? error.message
        : 'native_journey';
    try {
      if (find.byType(BoohtacordApp).evaluate().isNotEmpty &&
          Journey(output).state.phase == AppPhase.ready) {
        await Journey(output).capture('failure');
      }
    } catch (_) {
      // Keep the original bounded failure when no rendered fixture exists.
    }
    await File(path.join(output.path, 'failure.json')).writeAsString(
      jsonEncode({
        'status': 'FAIL',
        'reason': reason,
        'step': journey?.step ?? 'startup',
        'installed_build': installedBuild,
        if (journey != null &&
            find.byType(BoohtacordApp).evaluate().isNotEmpty) ...{
          'update_phase': journey.desktop.phase.name,
          'check_status': journey.app.updates.status.name,
          'check_result': journey.app.updates.result?.name,
          'banner_visible': journey.app.updates.visible,
          'policy_stale': journey.app.updates.stale,
          'policy_target_present': journey.app.updates.policy?.target != null,
          'native_failure': desktopUpdateFailureCode(journey.desktop.failure),
          'voice_phase': journey.state.voicePhase.name,
          'voice_connection_codes': voiceDiagnostics.codes,
          'ice_observation': voiceDiagnostics.ice,
          'expected_anchor': journey.restorationExpectedAnchor,
          'observed_anchor': journey.restorationObservedAnchor,
        },
      }),
      flush: true,
    );
  } finally {
    statsObservation?.cancel();
    await sdkObservation.cancel();
  }
}
