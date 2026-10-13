// QA-only observer. No metadata injection, subscription or independent stats loop.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_account_id/component.dart';

import 'qa98325_descriptor_observer.dart';

Map<String, Object?> qaReceiverDescriptorProjection(
  String? raw, {
  required String? expectedOrigin,
  required String? expectedAccountId,
  required String? expectedRoomId,
  bool publicationPresent = false,
  bool trackPresent = false,
  bool subscribed = false,
}) {
  final scoped =
      expectedOrigin != null &&
      expectedAccountId != null &&
      expectedRoomId != null;
  final parsed = scoped
      ? parseScreenShareDescriptor(
          raw,
          expectedOriginId: expectedOrigin,
          expectedAccountId: expectedAccountId,
          expectedRoomId: expectedRoomId,
        )
      : null;
  final bytes = raw == null ? null : utf8.encode(raw);
  final result = <String, Object?>{
    'schema_version': 1,
    'event': 'receiver_descriptor',
    'method': 'current_remote_attributes_production_scoped_parser',
    'descriptor_received': raw != null && raw.isNotEmpty,
    'descriptor_valid': parsed != null,
    'scope_verified': parsed != null,
    'descriptor_payload_sha256': bytes != null && bytes.length <= 4096
        ? sha256.convert(bytes).toString()
        : null,
    'remote_publication_present': publicationPresent,
    'remote_track_present': trackPresent,
    'remote_subscribed': subscribed,
    'publication_binding': 'v1_schema_has_no_publication_sid',
    'remote_capture_age': 'unknown',
    'sender_metrics_proven': false,
    'hardware_proven': false,
  };
  if (parsed != null) {
    result.addAll(
      publicDescriptorFields({
        'schema_version': 1,
        'mode': parsed.mode,
        'requested_profile_id': parsed.requestedProfileId,
        'publisher_state': parsed.publisherState,
        'profile_revision': parsed.profileRevision,
        'scope': {
          'publication_generation': parsed.publicationGeneration,
          'operation_revision': parsed.operationRevision,
        },
        'effective_profile': parsed.effectiveProfile,
      }),
    );
  }
  return result;
}

Map<String, Object?> qaObserveReceiverParticipant(
  RemoteParticipant participant, {
  required String? expectedOrigin,
  required String? expectedRoomId,
}) {
  final publication = participant.getTrackPublicationBySource(
    TrackSource.screenShareVideo,
  );
  return qaReceiverDescriptorProjection(
    participant.attributes[screenShareDescriptorAttribute],
    expectedOrigin: expectedOrigin,
    expectedAccountId: workspaceVoiceParticipantAccountId(participant),
    expectedRoomId: expectedRoomId,
    publicationPresent: publication != null,
    trackPresent: publication?.track is RemoteVideoTrack,
    subscribed: publication?.subscribed == true,
  );
}
