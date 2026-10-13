import 'dart:convert';

import 'model.dart';
import 'validation.dart';
import '../rollout/policy.dart';

const screenShareDescriptorAttribute = 'boohtacord.screen-share.v1';
const _maxBytes = 4096;
const _profileIds = {
  'P720_15',
  'P720_30',
  'P720_60',
  'P1080_15',
  'P1080_30',
  'P1080_60',
  'P1440_15',
  'P1440_30',
  'P1440_60',
};
const _modes = {'motion', 'text'};
const _publisherStates = {
  'idle',
  'requesting',
  'capturing',
  'publishing',
  'sharing',
  'updating',
  'stopping',
  'failed',
};
const _viewerStates = {
  'idle',
  'subscribing',
  'waiting-first-frame',
  'playing',
  'suspended',
  'recovering',
  'ended',
  'failed',
};
const _reasons = {
  'user-request',
  'platform-constraint',
  'network-adaptation',
  'no-subscribers',
  'sdk-paused',
  'unsupported-profile',
  'capture-denied',
  'publish-failed',
  'superseded',
  'session-revoked',
  'logout',
  'unknown',
};

ScreenShareSenderDescriptor? parseScreenShareDescriptor(
  String? raw, {
  String? expectedOriginId,
  String? expectedAccountId,
  String? expectedRoomId,
}) {
  if (!const ScreenMediaRollout().descriptor) return null;
  if (raw == null || raw.isEmpty || utf8.encode(raw).length > _maxBytes) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (!isMap(decoded)) return null;
  final value = decoded as JsonMap;
  if (!_valid(value)) return null;
  final scope = value['scope'] as JsonMap;
  if ((expectedOriginId != null && scope['origin_id'] != expectedOriginId) ||
      (expectedAccountId != null && scope['account_id'] != expectedAccountId) ||
      (expectedRoomId != null && scope['room_id'] != expectedRoomId)) {
    return null;
  }
  return ScreenShareSenderDescriptor(
    originId: scope['origin_id']! as String,
    accountId: scope['account_id']! as String,
    roomId: scope['room_id']! as String,
    mediaSessionId: scope['media_session_id']! as String,
    publicationGeneration: scope['publication_generation']! as int,
    operationRevision: scope['operation_revision']! as int,
    mode: value['mode']! as String,
    requestedProfileId: value['requested_profile_id']! as String,
    effectiveProfile: Map.unmodifiable(value['effective_profile']! as JsonMap),
    publisherState: value['publisher_state']! as String,
    viewerState: value['viewer_state']! as String,
    layerTopology: value['layer_topology']! as String,
    profileRevision: value['profile_revision']! as int,
    reasonCodes: List.unmodifiable(
      (value['reason_codes']! as List).cast<String>(),
    ),
  );
}

bool isNewerScreenShareDescriptor(
  ScreenShareSenderDescriptor candidate,
  ScreenShareSenderDescriptor current,
) {
  if (candidate.originId != current.originId ||
      candidate.accountId != current.accountId ||
      candidate.roomId != current.roomId) {
    return false;
  }
  if (candidate.publicationGeneration != current.publicationGeneration) {
    return candidate.publicationGeneration > current.publicationGeneration;
  }
  return candidate.mediaSessionId == current.mediaSessionId &&
      candidate.operationRevision > current.operationRevision;
}

bool _valid(JsonMap value) {
  const keys = [
    'schema_version',
    'scope',
    'mode',
    'publisher_state',
    'viewer_state',
    'requested_profile_id',
    'effective_profile',
    'layer_topology',
    'profile_revision',
    'capabilities',
    'reason_codes',
  ];
  final profile = value['requested_profile_id'];
  final mode = value['mode'];
  final reasons = value['reason_codes'];
  if (!exactKeys(value, keys) ||
      value['schema_version'] != 1 ||
      !validScope(value['scope']) ||
      !_profileIds.contains(profile) ||
      !_modes.contains(mode)) {
    return false;
  }
  return _remainingValid(value, reasons);
}

bool _remainingValid(JsonMap value, Object? reasons) {
  return _publisherStates.contains(value['publisher_state']) &&
      _viewerStates.contains(value['viewer_state']) &&
      validEffectiveProfile(value['effective_profile']) &&
      {'single-layer', 'bounded-simulcast'}.contains(value['layer_topology']) &&
      validWhole(value['profile_revision']) &&
      validCapabilities(value['capabilities']) &&
      reasons is List<Object?> &&
      reasons.length <= 8 &&
      reasons.toSet().length == reasons.length &&
      reasons.every(_reasons.contains);
}
