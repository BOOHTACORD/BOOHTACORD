import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/download.dart';

import 'package_fixture.dart';

class _RealHttp extends HttpOverrides {}

class _LocalTransport implements HttpClient {
  _LocalTransport(this.uri)
    : client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        _RealHttp(),
      );
  final Uri uri;
  final HttpClient client;
  @override
  Duration? get connectionTimeout => client.connectionTimeout;
  @override
  set connectionTimeout(Duration? v) => client.connectionTimeout = v;
  @override
  Duration get idleTimeout => client.idleTimeout;
  @override
  set idleTimeout(Duration v) => client.idleTimeout = v;
  @override
  Future<HttpClientRequest> getUrl(Uri original) => client.getUrl(uri);
  @override
  void close({bool force = false}) => client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpServer server;
  late Directory root;
  late File file;
  late Uri uri;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    uri = Uri.parse('http://127.0.0.1:${server.port}/asset');
    root = await Directory.systemTemp.createTemp('update-download-');
    file = File('${root.path}/package.partial');
  });
  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });
  test(
    'bounded retry uses no chat credentials and restarts changed Range safely',
    () async {
      final bytes = List<int>.generate(128, (i) => i);
      var calls = 0;
      await file.writeAsBytes(bytes.take(5).toList());
      await File('${file.path}.etag').writeAsString('"old"');
      server.listen((request) async {
        calls++;
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        expect(request.cookies, isEmpty);
        if (calls == 1) {
          request.response.statusCode = 503;
          await request.response.close();
          return;
        }
        expect(request.headers.value(HttpHeaders.ifRangeHeader), '"old"');
        request.response.headers.set(HttpHeaders.etagHeader, '"new"');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      await DesktopArtifactDownloader(clientFactory: () => _LocalTransport(uri))
          .download(
            await testPackage(bytes),
            file,
            DownloadCancellation(),
            (_, _) {},
          );
      expect(await file.readAsBytes(), bytes);
      expect(calls, 2);
    },
  );
  test('an HTTP or foreign redirect never reaches the transport', () async {
    var calls = 0;
    server.listen((request) async {
      calls++;
      request.response.statusCode = 302;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'http://foreign.invalid/package',
      );
      await request.response.close();
    });
    await expectLater(
      DesktopArtifactDownloader(clientFactory: () => _LocalTransport(uri))
          .download(
            await testPackage([1, 2]),
            file,
            DownloadCancellation(),
            (_, _) {},
          ),
      throwsA(isA<ArtifactFailure>()),
    );
    expect(calls, 1);
  });
  test(
    'changed ETag on 206 discards partial before a bounded full retry',
    () async {
      final bytes = List<int>.generate(128, (i) => i);
      await file.writeAsBytes(bytes.take(5).toList());
      await File('${file.path}.etag').writeAsString('"old"');
      var calls = 0;
      server.listen((request) async {
        calls++;
        if (calls == 1) {
          expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=5-');
          request.response.statusCode = 206;
          request.response.headers.set(HttpHeaders.etagHeader, '"changed"');
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 5-127/128',
          );
          request.response.add(bytes.skip(5).toList());
        } else {
          expect(request.headers.value(HttpHeaders.rangeHeader), isNull);
          expect(request.headers.value(HttpHeaders.ifRangeHeader), isNull);
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
        }
        await request.response.close();
      });
      await DesktopArtifactDownloader(clientFactory: () => _LocalTransport(uri))
          .download(
            await testPackage(bytes),
            file,
            DownloadCancellation(),
            (_, _) {},
          );
      expect(calls, 2);
      expect(await file.readAsBytes(), bytes);
      expect(await File('${file.path}.etag').exists(), isFalse);
    },
  );
}
