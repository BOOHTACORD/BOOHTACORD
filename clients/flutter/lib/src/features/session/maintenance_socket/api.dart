import 'dart:io';

import '../../../core/http/transport.dart';

class PublicMaintenanceApi {
  PublicMaintenanceApi(this.transport, {HttpClient Function()? createClient})
    : createClient = createClient ?? HttpClient.new;
  final ApiTransport transport;
  final HttpClient Function() createClient;
  HttpClient? _pending;

  void abort() {
    final client = _pending;
    _pending = null;
    client?.close(force: true);
  }

  Future<WebSocket> open() async {
    final server = transport.session.serverRevision;
    final base = Uri.parse(transport.session.baseUrl);
    if ((base.scheme != 'https' &&
            !(base.scheme == 'http' && base.host == '127.0.0.1')) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw StateError('Invalid public realtime origin');
    }
    final target = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/public/realtime',
    );
    if (_pending != null) throw StateError('Public realtime already opening');
    final client = createClient();
    _pending = client;
    late WebSocket socket;
    try {
      socket = await WebSocket.connect(target.toString(), customClient: client);
      if (!identical(_pending, client)) {
        await socket.close();
        throw StateError('Public realtime opening canceled');
      }
      _pending = null;
      client.close();
    } catch (_) {
      if (identical(_pending, client)) _pending = null;
      client.close(force: true);
      rethrow;
    }
    if (server != transport.session.serverRevision) {
      await socket.close();
      throw StateError('Public realtime server changed');
    }
    return socket;
  }
}
