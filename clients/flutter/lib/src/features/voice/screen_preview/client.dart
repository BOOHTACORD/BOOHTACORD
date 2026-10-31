import 'dart:typed_data';

import '../../../core/http/transport.dart';

const maxScreenPreviewBytes = 14 * 1024;
const _screenPreviewBeginTimeout = Duration(seconds: 30);
const _screenPreviewRequestTimeout = Duration(seconds: 3);

class ScreenPreviewFrame {
  const ScreenPreviewFrame(this.revision, this.jpeg);
  final int revision;
  final Uint8List jpeg;
}

class ScreenPreviewClient {
  const ScreenPreviewClient(this.transport);
  final ApiTransport transport;

  Future<String> begin(String leaseId) => transport.run(() async {
    final headers = await transport.headers();
    final response = await transport.raw
        .post(
          transport.uri('/voice/leases/$leaseId/screen-previews/v1'),
          headers: headers,
        )
        .timeout(_screenPreviewBeginTimeout);
    final body = await transport.checked(response);
    if (body is! Map<String, dynamic> ||
        body['schema_version'] != 1 ||
        body['generation_id'] is! String ||
        !_isUuid(body['generation_id'] as String)) {
      throw const FormatException('Invalid screen preview generation');
    }
    return body['generation_id'] as String;
  });

  Future<void> invalidate(String leaseId, String generationId) =>
      transport.run(() async {
        if (!_isUuid(leaseId) || !_isUuid(generationId)) return;
        final headers = await transport.headers();
        final response = await transport.raw
            .delete(
              transport.uri(
                '/voice/leases/$leaseId/screen-previews/v1/$generationId',
              ),
              headers: headers,
            )
            .timeout(_screenPreviewRequestTimeout);
        await transport.checked(response, acceptedStatuses: {204});
      });

  Future<ScreenPreviewFrame?> read(
    String leaseId,
    String generationId,
    int afterRevision,
  ) => transport.run(() async {
    final path = '/voice/screen-previews/v1/leases/$leaseId/$generationId';
    final headers = await transport.headers(accept: 'image/jpeg');
    headers['cache-control'] = 'no-store';
    headers['pragma'] = 'no-cache';
    final response = await transport.raw
        .get(
          transport.uri(path, {'after_revision': '$afterRevision'}),
          headers: headers,
        )
        .timeout(_screenPreviewRequestTimeout);
    if (response.statusCode == 204) {
      await transport.checked(response, acceptedStatuses: {204});
      return null;
    }
    await transport.checked(response);
    final revision = int.tryParse(
      response.headers['x-screen-preview-revision'] ?? '',
    );
    final contentType = response.headers['content-type']?.split(';').first;
    if (contentType != 'image/jpeg' ||
        revision == null ||
        revision <= afterRevision ||
        !validScreenPreviewJpeg(response.bodyBytes))
      return null;
    return ScreenPreviewFrame(revision, Uint8List.fromList(response.bodyBytes));
  });
}

bool validScreenPreviewJpeg(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes.length <= maxScreenPreviewBytes &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[bytes.length - 2] == 0xff &&
    bytes.last == 0xd9;

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
