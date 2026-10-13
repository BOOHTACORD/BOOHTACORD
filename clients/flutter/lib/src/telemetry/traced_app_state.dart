import '../features/telemetry/action_scope/action.dart';

import 'package:livekit_client/livekit_client.dart';

import '../app_state.dart';
import '../services/client_telemetry.dart';
import '../features/screen/profile/quality.dart';
import '../features/screen/profile/content_mode.dart';

class TracedAppState extends AppState {
  TracedAppState(super.api, {super.audioDeviceBootstrap}) {
    addListener(_watchVoiceReconnect);
  }

  ActionScope? _reconnectSpan;

  void _watchVoiceReconnect() {
    if (!ClientTelemetry.enabled) return;
    if (voicePhase == VoicePhase.reconnecting) {
      if (_reconnectSpan == null) {
        _reconnectSpan = ActionScope(
          'voice.reconnect',
          api.transport.session.telemetry,
          enabled: ClientTelemetry.enabled,
        );
        _reconnectSpan!.step('connect');
      }
    } else if (_reconnectSpan != null) {
      final failed =
          voicePhase != VoicePhase.connected &&
          voicePhase != VoicePhase.listener;
      final reason = voiceDisconnectNotice?.reason;
      final cancelled =
          failed && reason == null && voicePhase == VoicePhase.idle;
      final superseded = failed && reason == 'TRANSFER';
      final rejected =
          failed &&
          {
            'KICK',
            'BANNED',
            'CHANNEL_CLOSED',
            'SESSION_REVOKED',
            'LOGOUT',
          }.contains(reason);
      if (!failed) _reconnectSpan!.step('ready');
      _reconnectSpan!.finish(
        superseded
            ? 'superseded'
            : rejected
            ? 'rejected'
            : cancelled
            ? 'cancelled'
            : failed
            ? 'failed'
            : 'success',
        reason: superseded
            ? 'generation_changed'
            : rejected
            ? 'revoked'
            : cancelled
            ? 'disposed'
            : failed
            ? 'network'
            : 'none',
      );
      _reconnectSpan = null;
    }
  }

  @override
  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    ScreenShareContentMode? contentMode,
    VideoDimensions? sourceDimensions,
    bool captureScreenAudio = false,
  }) => ClientTelemetry.trace(
    'screen.share.start',
    () => super.startScreenShare(
      sourceId: sourceId,
      quality: quality,
      contentMode: contentMode,
      sourceDimensions: sourceDimensions,
      captureScreenAudio: captureScreenAudio,
    ),
    failed: () => screenSharePhase == ScreenSharePhase.error,
  );

  @override
  Future<void> stopScreenShare() =>
      ClientTelemetry.trace('screen.share.stop', super.stopScreenShare);

  @override
  void dispose() {
    removeListener(_watchVoiceReconnect);
    _reconnectSpan?.finish('cancelled', reason: 'disposed');
    super.dispose();
  }
}
