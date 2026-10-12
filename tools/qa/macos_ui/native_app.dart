import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/desktop_window_options.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class MacUiQaTls extends HttpOverrides {
  MacUiQaTls(this.pin);
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
    throw StateError('Owned macOS UI QA configuration required');
  }
  HttpOverrides.global = MacUiQaTls(pin);
  // Disposable QA credentials must never read or modify the user's Keychain.
  // The production API/cookie transport and all application widgets remain real.
  FlutterSecureStorage.setMockInitialValues({});
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
  String? lastSelectedChannel;
  var selectionGeneration = 0;
  void observe() {
    if (lastSelectedChannel != state.selectedChannel?.id) {
      lastSelectedChannel = state.selectedChannel?.id;
      selectionGeneration++;
    }
    final event = <String, Object?>{
      'phase': state.phase.name,
      'voice_phase': state.voicePhase.name,
      'workspace_panel': state.workspacePanel.name,
      'channel_selected': state.selectedChannel != null,
      'selection_revision': selectionGeneration,
      'profile_saving': state.profileSaving,
      'profile_error_present': state.error != null,
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
          'qa_mac_ui_state',
          jsonEncode({'status': 'OBSERVED', 'timeline': timeline}),
        ),
      );
    }
  }

  state.addListener(observe);
  Timer.periodic(const Duration(milliseconds: 300), (_) async {
    final size = await windowManager.getSize();
    await prefs.setString('qa_mac_ui_geometry', jsonEncode({
      'width': size.width, 'height': size.height,
      'voice_phase': state.voicePhase.name,
      'workspace_panel': state.workspacePanel.name,
      'selection_revision': selectionGeneration,
    }));
  });
  runApp(BoohtacordApp(state: state));
  try {
    await state.initialize();
    if (state.phase == AppPhase.ready) { await state.logout(); }
    await state.authenticate(const String.fromEnvironment('QA_LOGIN',defaultValue:'qa_admin'), password, register: false);
    state.toggleWorkspacePanel(WorkspacePanel.none);
    observe();
  } catch (e) {
    await prefs.setString(
      'qa_mac_ui_state',
      jsonEncode({
        'status': 'ERROR',
        'error_type': e.runtimeType.toString(),
        'timeline': timeline,
      }),
    );
  }
}
