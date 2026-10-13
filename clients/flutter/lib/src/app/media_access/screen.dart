import 'dart:typed_data';

import '../../services/screen_share_metrics.dart';

import 'package:livekit_client/livekit_client.dart';

import '../../features/screen/profile/quality.dart';
import '../../features/screen/profile/content_mode.dart';
import '../../features/screen/sender_metadata/latest_writer.dart';
import '../../features/screen/lifecycle/controller.dart';
import '../composition/owners.dart';
import '../media_preferences/screen.dart';

mixin AppScreenAccess on AppOwners {
  ScreenSharePhase get screenSharePhase => screen.phase;

  ScreenShareSenderReport? get screenShareSenderReport => screen.metrics.report;
  DateTime? get screenShareSenderSampledAt => screen.metrics.sampledAt;
  num? get screenShareTotalOutgoingBitrateBps => screen.metrics.totalBitrateBps;
  List<ScreenSenderLayerMetrics> get screenShareSenderLayers =>
      screen.metrics.layerDiagnostics;
  bool? get screenCapturedContentVisible => screen.capturedContentVisible;

  set screenSharePhase(ScreenSharePhase value) => screen.phase = value;

  String? get screenShareError => screen.error;

  set screenShareError(String? value) => screen.error = value;

  Map<String, Uint8List> get screenThumbnails => screen.thumbnails;

  ScreenShareQuality get screenShareQuality => screen.quality;
  String get screenShareSelectedProfileId => screen.selectedProfileId;
  ScreenShareQuality get screenShareSelectedQuality => screen.selectedQuality;
  ScreenShareContentMode get screenShareContentMode => screen.contentMode;
  String? get screenShareSenderDescriptorJson =>
      screen.descriptor.runtime.descriptorJson;

  ScreenDescriptorWriteStatus get screenShareDescriptorStatus =>
      screen.descriptor.runtime.status;
  DateTime? get screenShareDescriptorConfirmedAt =>
      screen.descriptor.runtime.confirmedAt;
  DateTime? get screenShareDescriptorAppliedAt =>
      screen.descriptor.runtime.appliedAt;

  set screenShareQuality(ScreenShareQuality value) => screen.quality = value;

  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
    bool captureScreenAudio = false,
    ScreenShareContentMode? contentMode,
  }) async {
    final preferences = captureScreenPreferences();
    await screen.startScreenShare(
      sourceId: sourceId,
      quality: quality,
      sourceDimensions: sourceDimensions,
      captureScreenAudio: captureScreenAudio,
      contentMode: contentMode,
    );
    if (screen.phase == ScreenSharePhase.sharing && screen.error == null) {
      await preferences?.save(screen.quality);
    }
  }

  Future<void> stopScreenShare() => screen.stopScreenShare();

  void updateScreenShareContentMode(ScreenShareContentMode value) =>
      screen.updateScreenShareContentMode(value);

  Future<void> updateScreenShareQuality(ScreenShareQuality quality) async {
    final preferences = captureScreenPreferences();
    await screen.updateScreenShareQuality(quality);
    if (screen.phase == ScreenSharePhase.sharing &&
        screen.error == null &&
        screen.quality == quality) {
      await preferences?.save(quality);
    }
  }
}
