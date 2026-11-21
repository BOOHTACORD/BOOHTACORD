import 'dart:io';

import '../../../core/http/transport.dart';
import '../../../services/client_telemetry.dart';
import '../../telemetry/action_scope/action.dart';
import '../lifecycle/liveness.dart';
import '../system_activity/capabilities.dart';
import '../system_activity/windows.dart';

class RealtimeConnectApi {
  RealtimeConnectApi(this.transport);
  final ApiTransport transport;

  Future<WebSocket> openRealtime({String? after, HttpClient? client}) async {
    final httpUri = Uri.parse(transport.session.baseUrl);
    final realtimeUri = httpUri.replace(
      scheme: httpUri.scheme == 'http' ? 'ws' : 'wss',
      path: '${httpUri.path}/realtime',
      queryParameters: {
        'capabilities': activityCapabilities(
          'role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1,notifications_v1,voice_roster_v2,maintenance_v1',
          isWindows: Platform.isWindows,
          initialIdle: _initialSystemIdle(),
        ),
        'after': ?after,
      },
    );
    final headers = await transport.headers();
    headers.addAll(ClientTelemetry.currentTraceHeaders());
    headers.addAll(ActionScope.current?.headers() ?? const {});
    final socket = await WebSocket.connect(
      realtimeUri.toString(),
      protocols: [heartbeatProtocol],
      headers: headers,
      customClient: client,
    );
    try {
      transport.ensureCurrent();
    } catch (_) {
      await socket.close();
      rethrow;
    }
    return socket;
  }
}

bool _initialSystemIdle() {
  if (!Platform.isWindows) return false;
  try {
    final source = WindowsSystemActivity();
    return initialIdleCapability(
      locked: source.readLocked(),
      idle: source.readIdle(),
    );
  } catch (_) {
    return false;
  }
}
