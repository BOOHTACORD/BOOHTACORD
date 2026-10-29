import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../core/http/api_failure.dart';
import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import 'client.dart';
import '../../screen/rollout/policy.dart';

class ScreenPreviewGenerationState {
  ScreenPreviewGenerationState(this.generation, this.revision);
  String generation;
  int revision, pending = 0;
  bool busy = false, poll = false;
  Timer? timer;
}

class ScreenPreviewReceiver {
  ScreenPreviewReceiver(this.owner, {bool? enabled})
      : enabled = enabled ?? const ScreenMediaRollout().jpegPreview;
  final VoiceController owner;
  final bool enabled;
  final states = <String, ScreenPreviewGenerationState>{};

  void updated(String lease, String generation, int revision) {
    if (!enabled) return;
    if (!_active(lease)) return;
    var state = states[lease];
    if (state?.generation != generation) {
      _clear(lease);
      state?.timer?.cancel();
      if (states.length >= 16) {
        final oldest = states.keys.first;
        states.remove(oldest)?.timer?.cancel();
        _clear(oldest);
      }
      state = ScreenPreviewGenerationState(generation, 0);
      states[lease] = state;
    }
    state!.pending = state.pending > revision ? state.pending : revision;
    if (!state.busy) unawaited(_pump(lease, state));
  }

  void invalidated(String lease, String generation) {
    final state = states[lease];
    if (state?.generation != generation) return;
    states.remove(lease);
    state?.timer?.cancel();
    _clear(lease);
  }

  void clear() {
    final leases = states.keys.toList();
    for (final state in states.values) {
      state.timer?.cancel();
    }
    states.clear();
    for (final lease in leases) { _clear(lease); }
  }

  bool _active(String lease) {
    final room = owner.room;
    final participant = room?.remoteParticipants['voice-lease:$lease'];
    return !owner.disposed && owner.leaseId != lease && participant != null &&
        participant.videoTrackPublications.any(
          (track) => track.source == TrackSource.screenShareVideo,
        );
  }

  Future<void> _pump(String lease, ScreenPreviewGenerationState state) async {
    state.busy = true;
    try {
      while (identical(states[lease], state) &&
          (state.pending > state.revision || state.poll)) {
        if (!_active(lease)) { invalidated(lease, state.generation); return; }
        final requested = state.pending;
        state.pending = state.revision;
        state.poll = false;
        try {
          final frame = await ScreenPreviewClient(owner.api.transport)
              .read(lease, state.generation, state.revision);
          if (!identical(states[lease], state)) return;
          if (frame != null && frame.revision > state.revision && _active(lease)) {
            state.revision = frame.revision;
            owner.screenThumbnails['voice-lease:$lease'] = frame.jpeg;
            owner.notifyListeners();
          } else if (requested > state.revision) {
            state.revision = requested;
          }
        } on ApiFailure catch (failure) {
          if (failure.status == 401 || failure.status == 403 || failure.status == 404) {
            invalidated(lease, state.generation);
            return;
          }
          if (!_active(lease)) { invalidated(lease, state.generation); return; }
        } catch (_) {
          if (!_active(lease)) { invalidated(lease, state.generation); return; }
        }
      }
    } finally {
      state.busy = false;
      if (identical(states[lease], state)) {
        state.timer?.cancel();
        state.timer = Timer(screenThumbnailCaptureInterval, () {
          if (!identical(states[lease], state)) return;
          if (!_active(lease)) { invalidated(lease, state.generation); return; }
          state.poll = true;
          unawaited(_pump(lease, state));
        });
      }
    }
  }

  void _clear(String lease) {
    owner.screenThumbnails.remove('voice-lease:$lease');
    owner.notifyListeners();
  }
}
