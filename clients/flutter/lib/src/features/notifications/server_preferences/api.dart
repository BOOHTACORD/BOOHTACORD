import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/transport.dart';
import 'client.dart';

class NotificationApi {
  NotificationApi(this.transport, this.account);
  final ApiTransport transport;
  final String account;
  Future<NotificationReply> send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) => transport.run(() async {
    final suffix = path.startsWith('/api/v1/')
        ? path.substring('/api/v1'.length)
        : path;
    if (!suffix.startsWith('/notification-')) {
      throw const NotificationPreferenceError(400);
    }
    final request = http.Request(method, transport.uri(suffix));
    request.followRedirects = false;
    request.headers.addAll(await transport.headers(jsonBody: body != null));
    request.headers['X-Notification-Account'] = account;
    if (body != null) request.body = jsonEncode(body);
    final response = await transport.client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 10));
    final decoded = await transport.checked(
      response,
      acceptedStatuses: {400, 404, 405, 409, 429, 503},
    );
    return NotificationReply(
      response.statusCode,
      decoded is Map<String, dynamic> ? decoded : {},
    );
  });
  Future<Map<String, dynamic>> checked(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final reply = await send(method, path, body);
    if (reply.status < 200 || reply.status >= 300) {
      throw NotificationPreferenceError(reply.status);
    }
    return reply.body;
  }
}
