import 'dart:convert';

import '../../../core/http/transport.dart';

class ScreenViewerPresenceApi {
  ScreenViewerPresenceApi(this.transport);

  final ApiTransport transport;

  Future<void> setPresence(
    String viewerLeaseId,
    String ownerLeaseId,
    String trackSid,
  ) async {
    _validateLeaseId(viewerLeaseId);
    _validateLeaseId(ownerLeaseId);
    _validateTrackSid(trackSid);
    await transport.checked(
      await transport.client.put(
        _viewerUri(viewerLeaseId, ownerLeaseId),
        headers: await transport.headers(jsonBody: true)
          ..['cache-control'] = 'no-store',
        body: jsonEncode({'track_sid': trackSid}),
      ),
    );
  }

  Future<void> stopPresence(
    String viewerLeaseId,
    String ownerLeaseId,
    String trackSid,
  ) async {
    _validateLeaseId(viewerLeaseId);
    _validateLeaseId(ownerLeaseId);
    _validateTrackSid(trackSid);
    await transport.checked(
      await transport.client.delete(
        _viewerUri(viewerLeaseId, ownerLeaseId, trackSid: trackSid),
        headers: await transport.headers()
          ..['cache-control'] = 'no-store',
      ),
    );
  }

  Future<void> clearOwnerAudience(
    String ownerLeaseId, {
    String? trackSid,
  }) async {
    _validateLeaseId(ownerLeaseId);
    if (trackSid != null) _validateTrackSid(trackSid);
    await transport.checked(
      await transport.client.delete(
        transport.uri(
          '/voice/leases/$ownerLeaseId/screen-viewers',
          trackSid == null ? null : {'track_sid': trackSid},
        ),
        headers: await transport.headers()
          ..['cache-control'] = 'no-store',
      ),
    );
  }

  Future<List<String>> readOwnerAudience(String ownerLeaseId) async {
    _validateLeaseId(ownerLeaseId);
    final response = await transport.checked(
      await transport.client.get(
        transport.uri('/voice/leases/$ownerLeaseId/screen-viewers'),
        headers: await transport.headers()
          ..['cache-control'] = 'no-store',
      ),
    );
    return _parseAudience(response);
  }

  Future<List<String>> readViewerAudience(
    String viewerLeaseId,
    String ownerLeaseId,
  ) async {
    _validateLeaseId(viewerLeaseId);
    _validateLeaseId(ownerLeaseId);
    final response = await transport.checked(
      await transport.client.get(
        _viewerUri(viewerLeaseId, ownerLeaseId),
        headers: await transport.headers()
          ..['cache-control'] = 'no-store',
      ),
    );
    return _parseAudience(response);
  }

  Uri _viewerUri(
    String viewerLeaseId,
    String ownerLeaseId, {
    String? trackSid,
  }) => transport.uri(
    '/voice/leases/$viewerLeaseId/screen-viewers/$ownerLeaseId',
    trackSid == null ? null : {'track_sid': trackSid},
  );

  static List<String> _parseAudience(dynamic response) {
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid screen viewer audience response.');
    }
    final accountIds = response['viewer_account_ids'];
    if (accountIds is! List ||
        accountIds.any((value) => value is! String || !_isUuid(value))) {
      throw const FormatException('Invalid screen viewer audience response.');
    }
    return accountIds
        .cast<String>()
        .map((id) => id.toLowerCase())
        .toSet()
        .toList(growable: false);
  }

  static void _validateLeaseId(String value) {
    if (!_isUuid(value)) throw ArgumentError.value(value, 'leaseId');
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  static void _validateTrackSid(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'trackSid');
    }
  }
}
