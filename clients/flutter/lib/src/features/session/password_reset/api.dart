import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class PasswordResetApi {
  PasswordResetApi(this.transport);
  final ApiTransport transport;

  Future<void> completePasswordReset(String token, String password) async {
    late final http.Response response;
    try {
      response = await transport.client.post(
        transport.uri('/auth/password-reset/complete'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'token': token, 'password': password}),
      );
    } catch (_) {
      throw const ApiFailure('Нет связи с сервером. Повторите попытку.');
    }
    if (response.statusCode == 204) {
      await transport.checked(response, reportUnauthorized: false);
      return;
    }
    if (response.statusCode == 400) {
      throw const ApiFailure(
        'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.',
        status: 400,
      );
    }
    if (response.statusCode == 429) {
      throw const ApiFailure(
        'Слишком много попыток. Подождите и повторите.',
        status: 429,
      );
    }
    if (response.statusCode == 503) {
      try {
        await transport.checked(response, reportUnauthorized: false);
      } on ApiFailure catch (error) {
        if (error.code == 'AUTH_BUSY') rethrow;
      }
    }
    throw ApiFailure(
      'Не удалось изменить пароль (${response.statusCode}). Повторите попытку.',
      status: response.statusCode,
    );
  }
}
