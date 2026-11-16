import 'dart:async';

import 'package:uuid/uuid.dart';

import '../lifecycle/controller.dart';
import '../metrics/telemetry_envelope.dart';
import '../rollout/policy.dart';
import 'confirmed_profile.dart';
import 'latest_writer.dart';
import 'native_readback.dart';
import 'parser.dart';
import 'runtime.dart';

class NativeScreenDescriptorBinding {
  NativeScreenDescriptorBinding(this.owner) {
    runtime = ScreenDescriptorRuntime(
      writer: LatestScreenProfileWriter(
        (lease, descriptor, abort) => owner.api.updateScreenProfileDescriptor(
          lease,
          descriptor,
          abortTrigger: abort,
        ),
        changed: (status) {
          runtime.recordWriteStatus(status);
          owner.changed();
        },
      ),
      readConfirmed: () async {
        final room = owner.readRoom(), track = owner.activeTrack;
        if (room == null ||
            track == null ||
            owner.qualityUpdateOperation != null) {
          return null;
        }
        final fresh = await readNativeScreenProfile(
          room,
          track,
          includeCodecStats: false,
        );
        if (owner.readRoom() == room &&
            identical(owner.activeTrack, track) &&
            owner.phase == ScreenSharePhase.sharing) {
          _confirmedCaptureWidth = _positiveInt(fresh?.capture['actual_width']);
          _confirmedCaptureHeight = _positiveInt(
            fresh?.capture['actual_height'],
          );
        }
        // Reuse the existing stats collector; metadata adds no getStats loop.
        String? codec;
        final sampledAt = owner.metrics.sampledAt;
        if (identical(owner.metrics.track, track) &&
            sampledAt != null &&
            DateTime.now().difference(sampledAt) < const Duration(seconds: 3)) {
          final codecs = owner.metrics.layerDiagnostics
              .map((row) => row.codec)
              .whereType<String>()
              .toSet();
          if (codecs.length == 1 && codecs.single.startsWith('video/')) {
            codec = codecs.single.substring(6);
          }
        }
        return fresh == null
            ? null
            : confirmedScreenProfile(
                fresh.capture,
                fresh.encodings,
                negotiatedCodec: codec,
              );
      },
      readIntent: () {
        return {
          'mode': owner.contentMode.name,
          'requested_profile_id': owner.selectedProfileId,
        };
      },
      changed: owner.changed,
    );
  }
  final ScreenShareController owner;
  late final ScreenDescriptorRuntime runtime;
  Timer? _timer;
  String? _lease, _publication, _track;
  String? _mediaSession;
  int _generation = 0;
  int? _confirmedCaptureWidth, _confirmedCaptureHeight;

  ScreenTelemetryPublicationScope? telemetryScope(String? activeLeaseId) {
    final trackId = owner.activeTrack?.mediaStreamTrack.id;
    final descriptor = runtime.lastDescriptor;
    final descriptorScope = descriptor?['scope'];
    if (owner.disposed ||
        owner.phase != ScreenSharePhase.sharing ||
        !owner.scope.capture().isActive ||
        activeLeaseId == null ||
        _lease != activeLeaseId ||
        _publication == null ||
        _track == null ||
        _track != trackId ||
        _mediaSession == null ||
        _generation < 1 ||
        runtime.status != ScreenDescriptorWriteStatus.applied ||
        descriptor?['publisher_state'] != 'sharing' ||
        descriptorScope is! Map ||
        descriptorScope['media_session_id'] != _mediaSession ||
        descriptorScope['publication_generation'] != _generation) {
      return null;
    }
    return ScreenTelemetryPublicationScope(
      ownerLeaseId: activeLeaseId,
      mediaSessionId: _mediaSession!,
      publicationGeneration: _generation,
      captureWidth: _confirmedCaptureWidth,
      captureHeight: _confirmedCaptureHeight,
      captureFps: owner.selectedQuality.frameRate,
    );
  }

  void published() {
    if (!const ScreenMediaRollout().descriptor) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    refresh();
  }

  void changeLease(String? lease) {
    if (_lease == lease) return;
    _lease = lease;
    _publication = null;
    _track = null;
    _mediaSession = null;
    _confirmedCaptureWidth = _confirmedCaptureHeight = null;
    runtime.invalidate();
    if (owner.activeTrack != null) refresh();
  }

  void refresh() {
    final room = owner.readRoom(), track = owner.activeTrack;
    final account = owner.readAccountId?.call(), lease = _lease;
    if (owner.disposed ||
        owner.phase != ScreenSharePhase.sharing ||
        room == null ||
        track == null ||
        account == null ||
        lease == null ||
        !owner.scope.capture().isActive) {
      return;
    }
    String? publication;
    for (final item in room.localParticipant?.videoTrackPublications ?? []) {
      if (identical(item.track, track)) publication = item.sid;
    }
    if (publication == null || publication.isEmpty) return;
    if (_publication != publication || _track != track.mediaStreamTrack.id) {
      _confirmedCaptureWidth = _confirmedCaptureHeight = null;
      final ticket = owner.scope.capture();
      final transport = owner.api.transport;
      final transportTicket = transport.session.scope.capture();
      final server = transport.session.serverRevision;
      final origin = transport.publicHeaders()['origin']!;
      final roomName = room.name;
      if (roomName == null || roomName.isEmpty) return;
      final previous = parseScreenShareDescriptor(
        room.localParticipant?.attributes[screenShareDescriptorAttribute],
        expectedOriginId: origin,
        expectedAccountId: account,
        expectedRoomId: roomName,
      );
      if (_track != track.mediaStreamTrack.id || _mediaSession == null) {
        _mediaSession = const Uuid().v4();
      }
      _track = track.mediaStreamTrack.id;
      _publication = publication;
      _generation =
          (_generation > (previous?.publicationGeneration ?? 0)
              ? _generation
              : previous?.publicationGeneration ?? 0) +
          1;
      // Scope ownership deliberately survives media stop so an idle descriptor
      // can clear this lease. Track/publication freshness is checked separately.
      bool current() =>
          !owner.disposed &&
          ticket.isActive &&
          transportTicket.isActive &&
          server == transport.session.serverRevision &&
          identical(owner.readRoom(), room) &&
          owner.readAccountId?.call() == account &&
          _lease == lease;
      runtime.activate(
        lease,
        {
          'origin_id': origin,
          'account_id': account,
          'room_id': roomName,
          'media_session_id': _mediaSession,
          'publication_generation': _generation,
        },
        current,
        operationRevision: previous?.operationRevision ?? 0,
        captureCurrent: () =>
            current() &&
            identical(owner.activeTrack, track) &&
            owner.phase == ScreenSharePhase.sharing &&
            (room.localParticipant?.videoTrackPublications.any(
                  (item) =>
                      identical(item.track, track) && item.sid == publication,
                ) ??
                false),
      );
    }
    unawaited(runtime.refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    runtime.stop();
    _publication = _track = _mediaSession = null;
    _confirmedCaptureWidth = _confirmedCaptureHeight = null;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    runtime.invalidate();
  }

  int? _positiveInt(Object? value) =>
      value is int && value > 0 && value <= 16384 ? value : null;
}
