import 'dart:async';

import 'validation.dart';

typedef ScreenViewerPresenceToggle = Future<void> Function(
  String viewerLeaseId,
  String ownerLeaseId,
  String trackSid,
  bool watching,
);
typedef ScreenViewerAudienceClear = Future<void> Function(
  String ownerLeaseId, {
  String? trackSid,
});
typedef ScreenViewerAudienceRead = Future<List<String>> Function(
  String ownerLeaseId,
);
typedef ScreenViewerAudienceReadForViewer = Future<List<String>> Function(
  String viewerLeaseId,
  String ownerLeaseId,
);
typedef ScreenViewerAudienceChanged = void Function(List<String> accountIds);

const screenViewerPresenceHeartbeat = Duration(seconds: 5);

class _Subscription {
  _Subscription({
    required this.viewerLeaseId,
    required this.ownerLeaseId,
    required this.trackSid,
  });

  final String viewerLeaseId;
  final String ownerLeaseId;
  final String trackSid;
  Timer? timer;
  bool pending = false;
  bool reported = false;
  bool? queuedWatching;
}

class ScreenViewerPresenceController {
  ScreenViewerPresenceController({
    required this.togglePresence,
    required this.clearOwnerAudience,
    required this.readOwnerAudience,
    required this.readViewerAudience,
    required this.onViewerAudienceChanged,
    required this.onOwnerAudienceChanged,
    this.heartbeatInterval = screenViewerPresenceHeartbeat,
  });

  final ScreenViewerPresenceToggle togglePresence;
  final ScreenViewerAudienceClear clearOwnerAudience;
  final ScreenViewerAudienceRead readOwnerAudience;
  final ScreenViewerAudienceReadForViewer readViewerAudience;
  final ScreenViewerAudienceChanged onViewerAudienceChanged;
  final ScreenViewerAudienceChanged onOwnerAudienceChanged;
  final Duration heartbeatInterval;

  Future<void>? _hintRefresh;
  bool _hintAgain = false;
  int _hintGeneration = 0;

  Future<void> refreshFromHint() {
    _hintAgain = true;
    return _hintRefresh ??= _drainHints(_hintGeneration);
  }

  Future<void> _drainHints(int generation) async {
    try {
      do {
        _hintAgain = false;
        await Future.wait([refreshSelectedAudience(), refreshOwnerAudience()]);
      } while (_hintAgain && generation == _hintGeneration);
    } finally {
      if (generation == _hintGeneration) _hintRefresh = null;
    }
  }

  final Map<String, _Subscription> _subscriptions = {};
  String? _selectedViewerLeaseId;
  String? _selectedOwnerLeaseId;
  String? _localOwnerLeaseId;
  String? _localOwnerTrackSid;
  Timer? _selectedAudienceTimer;
  Timer? _ownerAudienceTimer;
  int _selectedRead = 0, _ownerRead = 0;
  int _selectionRevision = 0;
  int _ownerRevision = 0;
  List<String> _viewerAccountIds = const [];
  List<String> _ownerAccountIds = const [];

  Future<void> selectAudience(String? viewerLeaseId, String? ownerLeaseId) {
    final nextViewer = isScreenViewerUuid(viewerLeaseId)
        ? viewerLeaseId!.toLowerCase()
        : null;
    final nextOwner = isScreenViewerUuid(ownerLeaseId)
        ? ownerLeaseId!.toLowerCase()
        : null;
    if (_selectedViewerLeaseId == nextViewer &&
        _selectedOwnerLeaseId == nextOwner) {
      return refreshSelectedAudience();
    }

    _selectedViewerLeaseId = nextViewer;
    _selectedOwnerLeaseId = nextOwner;
    _selectionRevision++;
    _selectedAudienceTimer?.cancel();
    _selectedAudienceTimer = null;
    _publishViewerAudience(const []);

    if (nextViewer == null || nextOwner == null) return Future<void>.value();
    _selectedAudienceTimer = Timer.periodic(heartbeatInterval, (_) {
      unawaited(refreshSelectedAudience());
    });
    return refreshSelectedAudience();
  }

  Future<void> remoteTrackSubscribed(
    String viewerLeaseId,
    String ownerLeaseId,
    String trackSid,
  ) {
    if (!isScreenViewerUuid(viewerLeaseId) ||
        !isScreenViewerUuid(ownerLeaseId) ||
        !isScreenViewerTrackSid(trackSid)) {
      return Future<void>.value();
    }
    final viewer = viewerLeaseId.toLowerCase();
    final owner = ownerLeaseId.toLowerCase();
    final key = _subscriptionKey(owner, trackSid);
    var subscription = _subscriptions[key];
    if (subscription == null) {
      subscription = _Subscription(
        viewerLeaseId: viewer,
        ownerLeaseId: owner,
        trackSid: trackSid,
      );
      _subscriptions[key] = subscription;
      subscription.timer = Timer.periodic(heartbeatInterval, (_) {
        unawaited(_send(subscription!, true));
      });
    }
    return _send(subscription, true);
  }

  Future<void> remoteTrackUnsubscribed(String ownerLeaseId, String trackSid) {
    if (!isScreenViewerUuid(ownerLeaseId) ||
        !isScreenViewerTrackSid(trackSid)) {
      return Future<void>.value();
    }
    final owner = ownerLeaseId.toLowerCase();
    final subscription = _subscriptions.remove(
      _subscriptionKey(owner, trackSid),
    );
    if (subscription == null) return Future<void>.value();
    subscription.timer?.cancel();
    subscription.timer = null;
    if (_selectedOwnerLeaseId == owner) {
      _selectionRevision++;
      _publishViewerAudience(const []);
    }
    return _send(subscription, false);
  }

  Future<void> participantDisconnected(String ownerLeaseId) async {
    if (!isScreenViewerUuid(ownerLeaseId)) return;
    final owner = ownerLeaseId.toLowerCase();
    final matches = _subscriptions.entries
        .where((entry) => entry.value.ownerLeaseId == owner)
        .toList(growable: false);
    for (final entry in matches) {
      _subscriptions.remove(entry.key);
      entry.value.timer?.cancel();
      entry.value.timer = null;
    }
    if (_selectedOwnerLeaseId == owner) {
      _selectionRevision++;
      _publishViewerAudience(const []);
    }
    await Future.wait(matches.map((entry) => _send(entry.value, false)));
  }

  Future<void> localTrackPublished(String ownerLeaseId, String trackSid) async {
    if (!isScreenViewerUuid(ownerLeaseId) ||
        !isScreenViewerTrackSid(trackSid)) {
      return;
    }
    final owner = ownerLeaseId.toLowerCase();
    final previousOwner = _localOwnerLeaseId;
    final previousTrack = _localOwnerTrackSid;
    final changed = previousOwner != owner || previousTrack != trackSid;
    if (changed) {
      _ownerAudienceTimer?.cancel();
      _ownerRevision++;
      _publishOwnerAudience(const []);
      if (previousOwner != null && previousTrack != null) {
        unawaited(_clearOwner(previousOwner, previousTrack));
      }
    }
    _localOwnerLeaseId = owner;
    _localOwnerTrackSid = trackSid;
    _ownerAudienceTimer ??= Timer.periodic(heartbeatInterval, (_) {
      unawaited(refreshOwnerAudience());
    });
    await refreshOwnerAudience();
  }

  Future<void> localTrackUnpublished(
    String ownerLeaseId,
    String trackSid,
  ) async {
    if (!isScreenViewerUuid(ownerLeaseId) ||
        !isScreenViewerTrackSid(trackSid)) {
      return;
    }
    final owner = ownerLeaseId.toLowerCase();
    if (_localOwnerLeaseId == owner && _localOwnerTrackSid == trackSid) {
      _ownerAudienceTimer?.cancel();
      _ownerAudienceTimer = null;
      _localOwnerLeaseId = null;
      _localOwnerTrackSid = null;
      _ownerRevision++;
      _publishOwnerAudience(const []);
    }
    await _clearOwner(owner, trackSid);
  }

  Future<void> refreshOwnerAudience() async {
    final owner = _localOwnerLeaseId;
    final track = _localOwnerTrackSid;
    if (owner == null || track == null) return;
    final revision = _ownerRevision, read = ++_ownerRead;
    try {
      final accounts = _normalizeAccountIds(await readOwnerAudience(owner));
      if (read != _ownerRead ||
          revision != _ownerRevision ||
          owner != _localOwnerLeaseId ||
          track != _localOwnerTrackSid) {
        return;
      }
      _publishOwnerAudience(accounts);
    } catch (_) {
      // Keep the last private audience snapshot while the API recovers.
    }
  }

  Future<void> refreshSelectedAudience() async {
    final viewer = _selectedViewerLeaseId;
    final owner = _selectedOwnerLeaseId;
    if (viewer == null || owner == null) return;
    final revision = _selectionRevision, read = ++_selectedRead;
    if (!_hasReportedSubscription(viewer, owner)) return;
    try {
      final accounts = _normalizeAccountIds(
        await readViewerAudience(viewer, owner),
      );
      if (read != _selectedRead ||
          revision != _selectionRevision ||
          viewer != _selectedViewerLeaseId ||
          owner != _selectedOwnerLeaseId ||
          !_hasReportedSubscription(viewer, owner)) {
        return;
      }
      _publishViewerAudience(accounts);
    } catch (_) {
      // Preserve the current audience while the private API snapshot recovers.
    }
  }

  Future<void> clear() async {
    _hintGeneration++;
    _hintAgain = false;
    _hintRefresh = null;
    _selectionRevision++;
    _ownerRevision++;
    _selectedAudienceTimer?.cancel();
    _ownerAudienceTimer?.cancel();
    _selectedAudienceTimer = null;
    _ownerAudienceTimer = null;
    _selectedViewerLeaseId = null;
    _selectedOwnerLeaseId = null;
    final owner = _localOwnerLeaseId;
    final ownerTrack = _localOwnerTrackSid;
    _localOwnerLeaseId = null;
    _localOwnerTrackSid = null;
    final subscriptions = _subscriptions.values.toList(growable: false);
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      subscription.timer?.cancel();
      subscription.timer = null;
    }
    _publishViewerAudience(const []);
    _publishOwnerAudience(const []);

    await Future.wait([
      ...subscriptions.map((subscription) => _send(subscription, false)),
      if (owner != null && ownerTrack != null) _clearOwner(owner, ownerTrack),
    ]);
  }

  Future<void> _send(_Subscription subscription, bool watching) async {
    if (subscription.pending) {
      subscription.queuedWatching = watching;
      return;
    }
    if (watching &&
        _subscriptions[_subscriptionKey(
              subscription.ownerLeaseId,
              subscription.trackSid,
            )] !=
            subscription) {
      return;
    }
    subscription.pending = true;
    var refreshSelected = false;
    try {
      await togglePresence(
        subscription.viewerLeaseId,
        subscription.ownerLeaseId,
        subscription.trackSid,
        watching,
      );
      if (watching &&
          _subscriptions[_subscriptionKey(
                subscription.ownerLeaseId,
                subscription.trackSid,
              )] ==
              subscription) {
        subscription.reported = true;
        if (_selectedViewerLeaseId == subscription.viewerLeaseId &&
            _selectedOwnerLeaseId == subscription.ownerLeaseId) {
          refreshSelected = true;
        }
      } else if (!watching) {
        subscription.reported = false;
      }
    } catch (_) {
      // The heartbeat retries a failed update; media playback stays independent.
    } finally {
      subscription.pending = false;
      final queuedWatching = subscription.queuedWatching;
      subscription.queuedWatching = null;
      if (queuedWatching != null && queuedWatching != watching) {
        await _send(subscription, queuedWatching);
      }
    }
    if (refreshSelected &&
        _subscriptions[_subscriptionKey(
              subscription.ownerLeaseId,
              subscription.trackSid,
            )] ==
            subscription &&
        subscription.reported) {
      await refreshSelectedAudience();
    }
  }

  Future<void> _clearOwner(String ownerLeaseId, String trackSid) async {
    try {
      await clearOwnerAudience(ownerLeaseId, trackSid: trackSid);
    } catch (_) {
      // Track-scoped cleanup is best-effort; the server also expires stale leases.
    }
  }

  bool _hasReportedSubscription(String viewerLeaseId, String ownerLeaseId) =>
      _subscriptions.values.any(
        (subscription) =>
            subscription.viewerLeaseId == viewerLeaseId &&
            subscription.ownerLeaseId == ownerLeaseId &&
            subscription.reported,
      );

  void _publishViewerAudience(List<String> next) {
    if (_sameAccounts(_viewerAccountIds, next)) return;
    _viewerAccountIds = List.unmodifiable(next);
    onViewerAudienceChanged(_viewerAccountIds);
  }

  void _publishOwnerAudience(List<String> next) {
    if (_sameAccounts(_ownerAccountIds, next)) return;
    _ownerAccountIds = List.unmodifiable(next);
    onOwnerAudienceChanged(_ownerAccountIds);
  }

  static String _subscriptionKey(String ownerLeaseId, String trackSid) =>
      '$ownerLeaseId\u0000$trackSid';

  static List<String> _normalizeAccountIds(List<String> values) => values
      .where(isScreenViewerUuid)
      .map((value) => value.toLowerCase())
      .toSet()
      .toList(growable: false);

  static bool _sameAccounts(List<String> left, List<String> right) =>
      left.length == right.length &&
      List<int>.generate(
        left.length,
        (index) => index,
      ).every((index) => left[index] == right[index]);
}
