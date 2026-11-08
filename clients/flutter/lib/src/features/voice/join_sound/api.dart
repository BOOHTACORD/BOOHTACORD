import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/http/transport.dart';

class JoinSoundApi {
  JoinSoundApi(this.transport, this.account);
  final ApiTransport transport;
  final String account;
  Future<Map<String, dynamic>?> current() => _manage('GET');
  Future<Map<String, dynamic>?> enable(bool value) =>
      _manage('PATCH', jsonEncode({'enabled': value}));
  Future<Map<String, dynamic>?> remove() => _manage('DELETE');
  Future<Map<String, dynamic>?> upload(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 2097152) {
      throw const FormatException('Файл должен быть не больше 2 МиБ.');
    }
    return _manage('POST', bytes);
  }

  Future<Map<String, dynamic>?> _manage(String method, [Object? body]) =>
      transport.run(() async {
        final request = http.Request(method, transport.uri('/me/join-sound'))
          ..followRedirects = false;
        request.headers.addAll(
          await transport.headers(jsonBody: body is String),
        );
        request.headers['X-Voice-Sound-Account'] = account;
        if (body is Uint8List) {
          request.headers['content-type'] = 'application/octet-stream';
          request.bodyBytes = body;
        } else if (body is String) {
          request.body = body;
        }
        final response = await transport.client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 15));
        final value = await transport.checked(
          response,
          acceptedStatuses: {404, 429},
        );
        if (method == 'GET' && response.statusCode == 404 ||
            response.statusCode == 204) {
          return null;
        }
        if (response.statusCode == 429) {
          throw const FormatException('Повторите загрузку через 10 секунд.');
        }
        if (value is! Map<String, dynamic> ||
            value['id'] is! String ||
            value['enabled'] is! bool ||
            value['revision'] is! int) {
          throw const FormatException('Некорректный ответ сервера.');
        }
        return value;
      });
  Future<Uint8List> download(String id) => transport.run(() async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      throw const FormatException('Invalid sound identifier');
    }
    final request = http.Request('GET', transport.uri('/voice/join-sounds/$id'))
      ..followRedirects = false;
    request.headers.addAll(await transport.headers(accept: 'audio/mpeg'));
    final response = await transport.client
        .send(request)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200 ||
        response.headers['content-type'] != 'audio/mpeg' ||
        response.headers['x-content-type-options'] != 'nosniff') {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Мелодия недоступна.');
    }
    final result = BytesBuilder();
    await for (final bytes in response.stream.timeout(
      const Duration(seconds: 3),
    )) {
      transport.ensureCurrent();
      if (result.length + bytes.length > 262144) {
        throw const FormatException('Мелодия слишком большая.');
      }
      result.add(bytes);
    }
    transport.ensureCurrent();
    if (result.isEmpty) throw const FormatException('Мелодия недоступна.');
    return result.takeBytes();
  });
}
