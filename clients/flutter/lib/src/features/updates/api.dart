import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model.dart';

export 'model.dart';

class UpdateApiFailure implements Exception {
  const UpdateApiFailure(this.message, {this.retryAfter});
  final String message;
  final Duration? retryAfter;
}

class UpdateApi {
  UpdateApi({http.Client? client, required this.baseUrl})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String Function() baseUrl;

  Future<UpdatePolicy> fetch(UpdateSelector selector) async {
    final uri = Uri.parse('${baseUrl()}/client-updates')
        .replace(queryParameters: selector.query);
    final response = await _client
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      final retry = response.statusCode == 404
          ? const Duration(minutes: 30)
          : response.statusCode == 429 && seconds != null
          ? Duration(seconds: seconds)
          : null;
      throw UpdateApiFailure(
        'Update check failed (${response.statusCode})',
        retryAfter: retry,
      );
    }
    if (response.bodyBytes.length > 32 * 1024 ||
        !(response.headers['content-type'] ?? '').contains('application/json'))
      throw const UpdateApiFailure('Invalid update response');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>)
      throw const FormatException('Invalid update policy');
    const policyKeys = {
      'application_family',
      'catalog_revision',
      'platform',
      'distribution',
      'channel',
      'arch',
      'state',
      'target',
    };
    if (!policyKeys.every(decoded.containsKey))
      throw const FormatException('Invalid update policy fields');
    final policy = UpdatePolicy.fromJson(decoded);
    if (policy.applicationFamily != 'boohtacord' ||
        policy.platform != selector.platform ||
        policy.distribution != selector.distribution ||
        policy.channel != selector.channel ||
        policy.arch != selector.arch ||
        policy.revision == null)
      throw const FormatException('Update selector mismatch');
    if ((policy.state == UpdatePolicyState.published) !=
        (policy.target != null))
      throw const FormatException('Invalid update policy state');
    final target = policy.target;
    if (target != null &&
        (target.version == null ||
            target.nativeBuild == null ||
            !['normal', 'important'].contains(target.priority) ||
            target.summary == null ||
            target.releaseNotesUrl == null ||
            target.actionKind == null ||
            target.actionUrl == null))
      throw const FormatException('Incomplete update target');
    if (target != null &&
        (!_safeUrl(target.releaseNotesUrl!) || !_safeUrl(target.actionUrl!)))
      throw const FormatException('Unsafe update URL');
    return policy;
  }
}

bool _safeUrl(String raw) {
  if (raw.length > 2048 || raw.startsWith('//')) return false;
  final value = Uri.tryParse(raw);
  if (value == null || value.userInfo.isNotEmpty) return false;
  return value.hasScheme ? value.scheme == 'https' : raw.startsWith('/');
}
