import 'dart:io';

import '../../../core/http/transport.dart';
import '../../../services/client_telemetry.dart';
import '../../telemetry/action_scope/action.dart';

class RealtimeConnectApi {
  RealtimeConnectApi(this.transport);
  final ApiTransport transport;

  Future<WebSocket> openRealtime({String? after}) async {
    final httpUri = Uri.parse(transport.session.baseUrl);
    final realtimeUri = httpUri.replace(
      scheme: httpUri.scheme == 'http' ? 'ws' : 'wss',
      path: '${httpUri.path}/realtime',
      queryParameters: {
        'capabilities': 'role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1',
        if (after != null) 'after': after,
      },
    );
    final headers = await transport.headers();
    headers.addAll(ClientTelemetry.currentTraceHeaders());
    headers.addAll(ActionScope.current?.headers() ?? const {});
    final socket = await WebSocket.connect(
      realtimeUri.toString(),
      headers: headers,
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
