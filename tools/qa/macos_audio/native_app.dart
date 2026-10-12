import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/desktop_window_options.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class MacAudioQaTls extends HttpOverrides {
  MacAudioQaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4850 &&
            sha256.convert(cert.der).toString() == pin;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const origin = String.fromEnvironment('QA_API_BASE');
  const pin = String.fromEnvironment('QA_CERT_SHA256');
  const password = String.fromEnvironment('QA_PASSWORD');
  if (!Platform.isMacOS ||
      origin != 'https://localhost:4850/api/v1' ||
      pin.length != 64 ||
      password.isEmpty) {
    throw StateError('Owned macOS audio QA configuration required');
  }
  HttpOverrides.global = MacAudioQaTls(pin);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('server_url', origin);
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(desktopWindowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  final state = AppState(
    ApiClient(),
    audioDeviceBootstrap: () async {
      await LiveKitClient.initialize();
      await rtc.ensurePeerConnectionFactoryReady();
    },
  );
  final timeline = <Map<String, Object?>>[];
  void observe() {
    final event = <String, Object?>{
      'phase': state.phase.name,
      'scan_status': state.audioDeviceScanStatus.name,
      'scan_failure': state.audioDeviceScanFailure?.name,
      'input_count': state.audioInputDevices.length,
      'output_count': state.audioOutputDevices.length,
      'input_selected': state.selectedAudioInputId != null,
      'output_selected': state.selectedAudioOutputId != null,
      'warning_present': state.audioDeviceWarning != null,
      'error_present': state.audioSettingsError != null,
    };
    if (timeline.isEmpty || jsonEncode(timeline.last) != jsonEncode(event)) {
      timeline.add(event);
      unawaited(
        prefs.setString(
          'qa_mac_audio_state',
          jsonEncode({'status': 'OBSERVED', 'timeline': timeline}),
        ),
      );
    }
  }

  state.addListener(observe);
  runApp(BoohtacordApp(state: state));
  try {
    await state.initialize();
    if (state.phase == AppPhase.ready) { await state.logout(); }
    await state.authenticate(const String.fromEnvironment('QA_LOGIN',defaultValue:'qa_admin'), password, register: false);
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    observe();
  } catch (e) {
    await prefs.setString(
      'qa_mac_audio_state',
      jsonEncode({
        'status': 'ERROR',
        'error_type': e.runtimeType.toString(),
        'timeline': timeline,
      }),
    );
  }
}
