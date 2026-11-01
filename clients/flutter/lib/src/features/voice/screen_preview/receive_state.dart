import 'dart:async';

import '../../../core/http/api_failure.dart';
import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import 'client.dart';
import '../../screen/rollout/policy.dart';

class ScreenPreviewGenerationState {
  ScreenPreviewGenerationState(this.generation, this.revision);
  String generation;
  int revision, pending = 0, initialReadFailures = 0;
  bool busy = false, poll = false;
  Timer? timer;
}

class ScreenPreviewReceiver {
  ScreenPreviewReceiver(this.owner, {bool? enabled})
    : enabled = enabled ?? const ScreenMediaRollout().jpegPreview;
  final VoiceController owner;
  final bool enabled;
  final states = <String, ScreenPreviewGenerationState>{};
  static const _leaseRetryInterval = Duration(seconds: 1);

  void updated(String lease, String generation, int revision) {
    if (!enabled) return;
    if (owner.disposed || owner.leaseId == lease) return;
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
    for (final lease in leases) {
      _clear(lease);
    }
  }

  bool _canRead(String lease) =>
      !owner.disposed && owner.leaseId != null && owner.leaseId != lease;

  Future<void> _pump(String lease, ScreenPreviewGenerationState state) async {
    state.busy = true;
    try {
      while (identical(states[lease], state) &&
          (state.pending > state.revision || state.poll)) {
        if (owner.disposed || owner.leaseId == lease) {
          states.remove(lease);
          state.timer?.cancel();
          return;
        }
        // Realtime can deliver the preview hint before voice admission has
        // installed the viewer lease. Keep it until the authenticated reader
        // can fetch the server-managed frame.
        if (!_canRead(lease)) break;
        final requested = state.pending;
        state.pending = state.revision;
        state.poll = false;
        try {
          final frame = await ScreenPreviewClient(owner.api.transport)
              .read(lease, state.generation, state.revision);
          if (!identical(states[lease], state)) return;
          if (frame != null &&
              frame.revision > state.revision &&
              _canRead(lease)) {
            state.revision = frame.revision;
            state.initialReadFailures = 0;
            owner.screenThumbnails['voice-lease:$lease'] = frame.jpeg;
            owner.notifyListeners();
          } else if (requested > state.revision) {
            // A hint can race the frame becoming readable. Keep its revision
            // pending and retry; never advance the cursor without receiving
            // the bytes for that revision.
            state.pending = state.pending > requested
                ? state.pending
                : requested;
            state.initialReadFailures++;
            break;
          }
        } on ApiFailure catch (failure) {
          if (failure.status == 401 ||
              failure.status == 403 ||
              failure.status == 404) {
            invalidated(lease, state.generation);
            return;
          }
          state.pending = state.pending > requested ? state.pending : requested;
          state.initialReadFailures++;
          break;
        } catch (_) {
          state.pending = state.pending > requested ? state.pending : requested;
          state.initialReadFailures++;
          break;
        }
      }
    } finally {
      state.busy = false;
      if (identical(states[lease], state)) {
        state.timer?.cancel();
        state.timer = Timer(
          !_canRead(lease) ||
                  (state.revision == 0 &&
                      state.pending > state.revision &&
                      state.initialReadFailures < 3)
              ? _leaseRetryInterval
              : screenThumbnailCaptureInterval,
          () {
            if (!identical(states[lease], state)) return;
            state.poll = true;
            unawaited(_pump(lease, state));
          },
        );
      }
    }
  }

  void _clear(String lease) {
    owner.screenThumbnails.remove('voice-lease:$lease');
    owner.notifyListeners();
  }
}
