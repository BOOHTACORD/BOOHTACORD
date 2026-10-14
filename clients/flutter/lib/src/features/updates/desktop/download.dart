import 'dart:async';
import 'dart:io';

import 'artifact.dart';

typedef DownloadProgress = void Function(int received, int total);

class DownloadCancellation {
  bool cancelled = false;
  HttpClient? _client;
  void cancel() {
    cancelled = true;
    _client?.close(force: true);
  }

  void check() {
    if (cancelled) throw const ArtifactFailure('cancelled');
  }
}

/// Intentionally separate from ApiClient: no session headers, cookies or tokens.
class DesktopArtifactDownloader {
  DesktopArtifactDownloader({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;
  final HttpClient Function() _clientFactory;
  Future<File> download(
    VerifiedInstallArtifact artifact,
    File partial,
    DownloadCancellation cancellation,
    DownloadProgress progress,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _once(artifact, partial, cancellation, progress);
      } on ArtifactFailure catch (error) {
        if (attempt >= 2 ||
            !['network', 'truncated', 'http'].contains(error.code))
          rethrow;
        for (var tick = 0; tick < (attempt + 1) * 10; tick++) {
          cancellation.check();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }

  Future<File> _once(
    VerifiedInstallArtifact artifact,
    File partial,
    DownloadCancellation cancellation,
    DownloadProgress progress,
  ) async {
    cancellation.check();
    var offset = await partial.exists() ? await partial.length() : 0;
    if (offset > artifact.size) {
      await partial.delete();
      offset = 0;
    }
    if (offset == artifact.size) {
      progress(offset, artifact.size);
      return partial;
    }
    final validatorFile = File('${partial.path}.etag');
    String? validator;
    try {
      if (await validatorFile.length() <= 512) {
        validator = await validatorFile.readAsString();
      }
    } catch (_) {}
    bool strong(String? value) =>
        value != null &&
        value.length <= 512 &&
        value.startsWith('"') &&
        value.endsWith('"') &&
        !value.contains('\n') &&
        !value.contains('\r');
    if (offset > 0 && !strong(validator)) {
      await partial.writeAsBytes([]);
      offset = 0;
    }
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 30);
    cancellation._client = client;
    IOSink? sink;
    try {
      var uri = artifact.downloadUrl;
      HttpClientResponse? response;
      for (var redirects = 0; redirects <= 5; redirects++) {
        cancellation.check();
        if (!_downloadHopAllowed(uri, initial: redirects == 0)) {
          throw const ArtifactFailure('redirect');
        }
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        if (offset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
          request.headers.set(HttpHeaders.ifRangeHeader, validator!);
        }
        response = await request.close().timeout(const Duration(seconds: 30));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final next = response.headers.value(HttpHeaders.locationHeader);
          if (next == null) throw const ArtifactFailure('redirect');
          uri = uri.resolve(next);
          await response.drain<void>().timeout(const Duration(seconds: 5));
          response = null;
          continue;
        }
        break;
      }
      if (response == null) throw const ArtifactFailure('redirect_limit');
      if (response.statusCode == 200) {
        offset = 0;
        final etag = response.headers.value(HttpHeaders.etagHeader);
        if (strong(etag)) {
          await validatorFile.writeAsString(etag!, flush: true);
        } else if (await validatorFile.exists()) {
          await validatorFile.delete();
        }
      } else if (response.statusCode == 206 && offset > 0) {
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        if (response.headers.value(HttpHeaders.etagHeader) != validator ||
            range == null ||
            !range.startsWith('bytes $offset-') ||
            !range.endsWith('/${artifact.size}')) {
          throw const ArtifactFailure('range');
        }
      } else {
        throw const ArtifactFailure('http');
      }
      if (response.contentLength >= 0 &&
          response.contentLength != artifact.size - offset) {
        throw const ArtifactFailure('size');
      }
      sink = partial.openWrite(
        mode: offset == 0 ? FileMode.write : FileMode.append,
      );
      var received = offset;
      final deadline = DateTime.now().add(const Duration(minutes: 30));
      await for (final bytes in response.timeout(const Duration(seconds: 30))) {
        cancellation.check();
        if (DateTime.now().isAfter(deadline)) {
          throw const ArtifactFailure('timeout');
        }
        received += bytes.length;
        if (received > artifact.size) throw const ArtifactFailure('size');
        sink.add(bytes);
        await sink.flush();
        progress(received, artifact.size);
        // Flush each chunk so downloads are back-pressured and memory stays bounded.
      }
      await sink.flush();
      if (received != artifact.size) throw const ArtifactFailure('truncated');
      cancellation.check();
      return partial;
    } on ArtifactFailure {
      rethrow;
    } catch (_) {
      cancellation.check();
      throw const ArtifactFailure('network');
    } finally {
      await sink?.close();
      client.close(force: true);
      cancellation._client = null;
    }
  }
}

bool _downloadHopAllowed(Uri uri, {required bool initial}) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443)) {
    return false;
  }
  if (initial) return officialArtifactUrl(uri.toString());
  return uri.host == 'github.com' ||
      uri.host == 'release-assets.githubusercontent.com' ||
      uri.host == 'objects.githubusercontent.com';
}
