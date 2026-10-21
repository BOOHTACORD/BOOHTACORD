import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/tracing_http_client.dart';
import '../session/session_store.dart';
import 'api_failure.dart';
import 'request_scope.dart';
import 'scoped_client.dart';

class ApiTransport {
  ApiTransport({http.Client? client}) : raw = client ?? http.Client() {
    this.client = ScopedHttpClient(
      TracingHttpClient(raw, session.telemetry),
      session.scope,
    );
  }
  final http.Client raw;
  late final http.Client client;
  final SessionStore session = SessionStore();
  Future<T> run<T>(Future<T> Function() operation, {bool allowClosed = false}) {
    final server = session.serverRevision;
    return RequestScope(
      session.scope.capture(),
      allowClosed: allowClosed,
      sameServer: () => server == session.serverRevision,
    ).run(operation);
  }

  void ensureCurrent() => RequestScope.current?.ensureCurrent();
  Future<void> clearSessionCookie() async {
    ensureCurrent();
    await session.clearCookie(ticket: RequestScope.current?.ticket);
    ensureCurrent();
  }

  Map<String, String> publicHeaders({String accept = 'application/json'}) {
    final server = Uri.parse(session.baseUrl);
    return {
      'accept': accept,
      'origin': '${server.scheme}://${server.authority}',
    };
  }

  Future<Map<String, String>> headers({
    bool jsonBody = false,
    String accept = 'application/json',
  }) async {
    ensureCurrent();
    final cookie = await session.readCookie();
    ensureCurrent();
    return {
      ...publicHeaders(accept: accept),
      if (jsonBody) 'content-type': 'application/json',
      'cookie': ?cookie,
    };
  }

  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${session.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> checked(
    http.Response response, {
    bool reportUnauthorized = true,
    Set<int> acceptedStatuses = const {},
  }) async {
    ensureCurrent();
    final ticket = RequestScope.current?.ticket ?? session.scope.capture();
    session.telemetry.bindInstallation(response.headers['x-installation-id']);
    session.telemetry.bind(
      response.headers['x-telemetry-session'],
      response.headers['x-telemetry-schema'],
    );
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final pair = setCookie.split(';').first;
      if (pair.endsWith('=')) {
        await session.clearCookie(ticket: ticket);
      } else {
        await session.writeCookie(pair, ticket: ticket);
      }
    }
    ensureCurrent();
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }
    if ((response.statusCode >= 200 && response.statusCode < 300) ||
        acceptedStatuses.contains(response.statusCode)) {
      return decoded;
    }
    if (response.statusCode == 401) {
      await session.clearCookie(ticket: ticket);
      ensureCurrent();
      if (reportUnauthorized) session.onUnauthorized?.call();
    }
    String? code;
    String? message;
    if (decoded is Map<String, dynamic> &&
        decoded['error'] is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>;
      code = error['code'] as String?;
      message = error['message'] as String?;
    }
    throw ApiFailure(
      message ?? 'Запрос отклонён сервером (${response.statusCode}).',
      status: response.statusCode,
      code: code,
    );
  }
}
