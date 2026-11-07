import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/transport.dart';
import 'schema.dart';

class VoiceSoundPreferenceConflict implements Exception {
  const VoiceSoundPreferenceConflict();
}

class VoiceSoundPreferencesApi {
  VoiceSoundPreferencesApi(this.transport, this.account);
  final ApiTransport transport;
  final String account;
  static const _path = '/me/voice-sound-preferences';

  Future<VoiceSoundSnapshot> load() => _request('GET');

  Future<VoiceSoundSnapshot> patch(
    int revision,
    Map<String, dynamic> change,
  ) async {
    if (revision < 0) throw const FormatException('Invalid revision');
    final captured = Map<String, dynamic>.of(change);
    validateSoundChanges(captured);
    final result = await _request('PATCH', {
      'expected_revision': revision,
      ...captured,
    });
    if (result.revision <= revision ||
        captured.entries.any(
          (entry) => result.settings[entry.key] != entry.value,
        )) {
      throw const FormatException('Unacknowledged preferences');
    }
    return result;
  }

  Future<VoiceSoundSnapshot> _request(
    String method, [
    Map<String, dynamic>? body,
  ]) => transport.run(() async {
    final request = http.Request(method, transport.uri(_path));
    request.followRedirects = false;
    request.headers.addAll(await transport.headers(jsonBody: body != null));
    request.headers['X-Voice-Sound-Account'] = account;
    if (body != null) request.body = jsonEncode(body);
    final response = await transport.client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 10));
    final value = await transport.checked(response, acceptedStatuses: {409});
    if (response.statusCode == 409) throw const VoiceSoundPreferenceConflict();
    return VoiceSoundSnapshot.parse(value);
  });
}
