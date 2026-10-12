import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class HeldResponse {
  HeldResponse(this.matches);
  final bool Function(Uri) matches;
  final captured = Completer<void>();
  final release = Completer<void>();
  int? revision;
}

// Fault injection delays actual replies; status, headers and body are unchanged.
class DelayedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final clock = Stopwatch()..start();
  final events = <Map<String, Object?>>[];
  HeldResponse? _next;
  final _held = <HeldResponse>[];
  HeldResponse holdNext(bool Function(Uri) matches) {
    if (_next != null) throw StateError('Only one armed reply per phase');
    final value = HeldResponse(matches);
    _held.add(value);
    _next = value;
    return value;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final held = _next?.matches(request.url) == true ? _next : null;
    if (held != null) _next = null;
    final incoming = await _inner.send(request);
    final path = request.url.path;
    final route = path.endsWith('/avatar')
        ? 'protected_avatar'
        : path.endsWith('/me')
        ? 'own_profile'
        : RegExp(r'/members/[^/]+$').hasMatch(path)
        ? 'member_profile'
        : path.endsWith('/members')
        ? 'members_page'
        : null;
    if (route == null && held == null) return incoming;
    final response = await http.Response.fromStream(incoming);
    int? revision;
    if (route == 'own_profile' || route == 'member_profile') {
      try {
        revision =
            (jsonDecode(response.body)
                    as Map<String, dynamic>)['profile_revision']
                as int?;
      } catch (_) {
        /* status suffices */
      }
    }
    if (route != null) {
      events.add({
        'route': route,
        'status': response.statusCode,
        'profile_revision': ?revision,
        if (route == 'protected_avatar')
          'revision_query_present':
              int.tryParse(request.url.queryParameters['revision'] ?? '') !=
              null,
        'at_ms': clock.elapsedMilliseconds,
        'held': held != null,
      });
    }
    if (held != null) {
      held.revision = revision;
      held.captured.complete();
      await held.release.future;
      events.add({
        'route': route,
        'released_at_ms': clock.elapsedMilliseconds,
        'profile_revision': revision,
      });
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      contentLength: response.bodyBytes.length,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    for (final held in _held) {
      if (!held.release.isCompleted) held.release.complete();
    }
    _inner.close();
    super.close();
  }
}
