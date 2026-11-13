import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admission_response.dart';

import '../../../models.dart';
import '../../../core/http/transport.dart';

class AuthSessionApi {
  AuthSessionApi(this.transport);
  final ApiTransport transport;

  Future<SessionUser?> currentSession({
    Future<void>? abortTrigger,
    bool Function()? isCurrent,
  }) async {
    final uri = transport.uri('/auth/session');
    final headers = await transport.headers();
    if (isCurrent?.call() == false) throw http.RequestAbortedException(uri);
    final http.Response response;
    if (abortTrigger == null) {
      response = await transport.client.get(uri, headers: headers);
    } else {
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abortTrigger,
      )..headers.addAll(headers);
      response = await http.Response.fromStream(
        await transport.client.send(request),
      );
    }
    if (isCurrent?.call() == false) throw http.RequestAbortedException(uri);
    if (response.statusCode == 401) {
      await transport.clearSessionCookie();
      return null;
    }
    final data = await transport.checked(response) as Map<String, dynamic>;
    if (data['authenticated'] == false) return null;
    return SessionUser.fromJson(data);
  }

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    final body = jsonEncode({'login': login, 'password': password});
    if (register) {
      await checkAuthenticationResponse(
        transport,
        await transport.client.post(
          transport.uri('/auth/register'),
          headers: await transport.headers(jsonBody: true),
          body: body,
        ),
      );
    }
    await checkAuthenticationResponse(
      transport,
      await transport.client.post(
        transport.uri('/auth/login'),
        headers: await transport.headers(jsonBody: true),
        body: body,
      ),
    );
  }

  Future<void> logout() async {
    await transport.checked(
      await transport.client.post(
        transport.uri('/auth/logout'),
        headers: await transport.headers(),
      ),
    );
    await transport.clearSessionCookie();
  }
}
