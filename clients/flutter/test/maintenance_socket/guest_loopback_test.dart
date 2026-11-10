import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/api.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/guest.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';

class LoopbackOverrides extends HttpOverrides {
  HttpClient create() => super.createHttpClient(null);
}

void main() {
  test(
    'real guest socket sends no cookie and accepts only public state',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = ApiTransport();
      transport.session.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
      final observed = Completer<void>(), ready = Completer<void>();
      WebSocket? peer;
      final requests = server.listen((request) async {
        expect(request.uri.path, '/api/v1/public/realtime');
        expect(request.uri.query, isEmpty);
        expect(request.headers.value('cookie'), isNull);
        peer = await WebSocketTransformer.upgrade(request);
        peer!.listen((_) => fail('guest sent application data'));
        for (final item in [
          {
            'event_id': 'ready',
            'kind': 'connection.ready',
            'occurred_at': '2026-11-09T00:00:00Z',
            'payload': <String, dynamic>{},
          },
          {
            'event_id': 'state',
            'kind': 'maintenance.snapshot',
            'occurred_at': '2026-11-09T00:00:00Z',
            'payload': {
              'version': 1,
              'generation': '11111111-1111-4111-8111-111111111111',
              'revision': 1,
              'active': true,
            },
          },
        ]) {
          peer!.add(jsonEncode(item));
        }
        observed.complete();
      });
      final state = MaintenanceSocketState();
      state.addListener(() {
        if (state.known && !ready.isCompleted) ready.complete();
      });
      final guest = MaintenanceGuestSocket(
        state,
        PublicMaintenanceApi(
          transport,
          createClient: LoopbackOverrides().create,
        ).open,
      );
      try {
        guest.start();
        await observed.future.timeout(const Duration(seconds: 5));
        await ready.future.timeout(const Duration(seconds: 5));
        expect(state.active, isTrue);
      } finally {
        await guest.stop();
        state.dispose();
        await peer?.close();
        await requests.cancel();
        await server.close(force: true);
        transport.raw.close();
      }
    },
  );
}
