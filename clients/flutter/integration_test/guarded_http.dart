import 'package:http/http.dart' as http;

// Test-only observation of requests; never records headers, bodies or URLs.
class GuardedHttpClient extends http.BaseClient {
  GuardedHttpClient({http.Client? delegate})
    : _delegate = delegate ?? http.Client();
  final http.Client _delegate;
  int legacyRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final path = request.url.path;
    if (path == '/api/v1/maintenance/events' ||
        path == '/api/v1/voice/rosters/events') {
      legacyRequests++;
      throw StateError('Legacy realtime request refused by QA');
    }
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}
