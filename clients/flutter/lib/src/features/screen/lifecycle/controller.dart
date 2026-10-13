import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../profile/quality.dart';
import '../profile/content_mode.dart';
import '../../../services/screen_thumbnail.dart';
import '../capture/driver.dart';
import '../metrics/factory.dart';
import '../thumbnail_state/controller.dart';
import 'captured_content_visibility.dart';
import 'visibility_subscription.dart';
import 'initialize.dart';
import '../runtime_apply/options.dart';
import '../runtime_apply/runtime.dart';
import 'stop.dart';
import 'types.dart';
import '../sender_metadata/binding.dart';
export 'types.dart';
export 'start.dart';
export 'stop.dart';
export 'events.dart';
export '../quality/update.dart';

class ScreenShareController extends ChangeNotifier {
  ScreenShareController(
    this.api,
    this.scope, {
    required this.readRoom,
    required this.voiceReady,
    this.readAccountId,
    ScreenShareDriver? driver,
    ScreenAdaptationOptions adaptationOptions = const ScreenAdaptationOptions(),
  }) : driver = driver ?? NativeScreenShareDriver() {
    initializeScreenSharing(this, adaptationOptions);
    descriptor = NativeScreenDescriptorBinding(this);
    _capturedContentVisibilitySubscription = subscribeCapturedVisibility(
      handleCapturedContentVisibility,
    );
  }
  final ApiClient api;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() voiceReady;
  final String? Function()? readAccountId;
  late final NativeScreenDescriptorBinding descriptor;
  final ScreenShareDriver driver;
  late final ScreenShareMetricsController metrics;
  late final ScreenAdaptationRuntime adaptation;
  ScreenShareQuality? userQualityCeiling;
  ScreenShareQuality get selectedQuality => userQualityCeiling ?? quality;
  String get selectedProfileId {
    final selected = selectedQuality;
    return 'P${selected.resolution}_${selected.frameRate}';
  }

  int manualQualityRevision = 0;
  late final ScreenThumbnailController thumbnail;
  final Map<String, Uint8List> thumbnails = {};
  final captureQueue = ScreenThumbnailCaptureQueue();
  final CapturedContentVisibilityState capturedContentVisibility =
      CapturedContentVisibilityState();
  StreamSubscription<rtc.CapturedContentVisibilityEvent>?
  _capturedContentVisibilitySubscription;
  ScreenSharePhase phase = ScreenSharePhase.idle;
  String? error;
  bool captureRestartRequired = false;
  ScreenShareContentMode contentMode = ScreenShareContentMode.motion;
  ScreenShareQuality quality =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? ScreenShareQuality.balanced
      : ScreenShareQuality.desktopDefault;
  int revision = 0;
  int qualityIntentRevision = 0;
  ScreenShareQuality? pendingQualityUpdate;
  SessionTicket? pendingQualityTicket, pendingQualityTransportTicket;
  int pendingQualityServer = 0;
  Room? pendingQualityRoom;
  int pendingQualityLifecycleRevision = 0;
  Future<void>? qualityUpdateOperation;
  bool disposed = false;
  Future<void>? starting;
  Future<void>? closing;
  LocalVideoTrack? activeTrack;
  VideoDimensions? sourceDimensions;
  bool? get capturedContentVisible => capturedContentVisibility.isVisible;

  void handleCapturedContentVisibility(
    rtc.CapturedContentVisibilityEvent event,
  ) {
    if (capturedContentVisibility.handle(event)) changed();
  }

  bool current(SessionTicket ticket, int expected, Room room) =>
      !disposed &&
      ticket.isActive &&
      expected == revision &&
      identical(readRoom(), room);
  void changed() {
    if (!disposed) notifyListeners();
  }

  void updateScreenShareContentMode(ScreenShareContentMode value) {
    if (disposed || contentMode == value) return;
    contentMode = value;
    descriptor.refresh();
    changed();
  }

  Future<void> stopSampling() async {
    metrics.stop();
    await thumbnail.stop();
  }

  Future<void> previewLeaseChanged(String? leaseId) {
    descriptor.changeLease(leaseId);
    return thumbnail.changeLease(leaseId);
  }

  @override
  void dispose() {
    adaptation.invalidate();
    disposed = true;
    descriptor.dispose();
    unawaited(_capturedContentVisibilitySubscription?.cancel());
    unawaited(stopScreenShare());
    super.dispose();
  }
}
