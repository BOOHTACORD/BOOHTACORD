import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

/// Sparkle deliberately accepts HTTP(S), not file URLs. This short-lived loopback
/// transport serves exactly the already-authenticated package. EdDSA remains on.
class SelectedPackageFeed {
  SelectedPackageFeed._(this._server, this._token);
  final HttpServer _server;
  final String _token;
  Timer? _deadline;
  Uri get archiveUrl =>
      Uri.parse('http://127.0.0.1:${_server.port}/$_token/update.zip');
  Uri get feedUrl => archiveUrl.resolve('appcast.xml');
  static Future<SelectedPackageFeed> start(
    File archive, {
    required String build,
    required String version,
    required String signature,
  }) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final feed = SelectedPackageFeed._(server, const Uuid().v4());
    final length = await archive.length();
    String escape(String raw) =>
        const HtmlEscape(HtmlEscapeMode.attribute).convert(raw);
    final xml =
        '<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>BOOHTACORD</title><item><title>Update</title><enclosure url="${feed.archiveUrl}" length="$length" type="application/octet-stream" sparkle:version="${escape(build)}" sparkle:shortVersionString="${escape(version)}" sparkle:edSignature="${escape(signature)}"/></item></channel></rss>';
    var requests = 0;
    server.listen((request) async {
      try {
        if (++requests > 16 ||
            !request.connectionInfo!.remoteAddress.isLoopback ||
            !['GET', 'HEAD'].contains(request.method) ||
            request.uri.hasQuery ||
            ![
              feed.feedUrl.path,
              feed.archiveUrl.path,
            ].contains(request.uri.path)) {
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.uri.path == feed.feedUrl.path) {
          final bytes = utf8.encode(xml);
          request.response.headers.contentType = ContentType(
            'application',
            'rss+xml',
            charset: 'utf-8',
          );
          request.response.contentLength = bytes.length;
          if (request.method == 'GET') request.response.add(bytes);
        } else {
          request.response.headers.contentType = ContentType.binary;
          request.response.contentLength = length;
          if (request.method == 'GET') {
            await request.response.addStream(archive.openRead());
          }
        }
        await request.response.close();
      } catch (_) {
        await request.response.close().catchError((Object _) {});
      }
    });
    feed._deadline = Timer(
      const Duration(minutes: 10),
      () => unawaited(feed.close()),
    );
    return feed;
  }

  Future<void> close() async {
    _deadline?.cancel();
    await _server.close(force: true);
  }
}
