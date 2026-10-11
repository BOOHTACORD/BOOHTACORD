import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/desktop_window_options.dart';
import 'src/services/api_client.dart';
import 'src/services/third_party_audio_licenses.dart';
import 'src/services/client_telemetry.dart';
import 'src/telemetry/traced_app_state.dart';
import 'src/features/updates/api.dart';
import 'src/features/updates/controller.dart';
import 'src/features/updates/identity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyAudioLicenses();
  if (Platform.isAndroid) {
    await rtc.WebRTC.initialize(
      options: {'androidUseHardwareNoiseSuppression': false},
    );
  }
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(desktopWindowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final api = ApiClient();
  ClientTelemetry.session = api.transport.session.telemetry;
  await ClientTelemetry.initialize(api.submitClientSpans);
  final state = TracedAppState(
    api,
    audioDeviceBootstrap: Platform.isMacOS
        ? () async {
            // Apply the same WebRTC options as a normal LiveKit startup before
            // the plugin bootstrap makes its process-wide factory and ADM.
            await LiveKitClient.initialize();
            await rtc.ensurePeerConnectionFactoryReady();
          }
        : null,
  );
  final updates = UpdateController(
    api: UpdateApi(baseUrl: () => api.baseUrl),
    identity: await NativeUpdateIdentity.load(),
  );
  runApp(BoohtacordApp(state: state, updates: updates));
  await state.initialize();
  updates.start();
}
