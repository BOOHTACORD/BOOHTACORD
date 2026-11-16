import 'controller.dart';
import '../runtime_apply/binding.dart';
import '../runtime_apply/options.dart';
import '../runtime_apply/runtime.dart';
import '../metrics/factory.dart';
import '../thumbnail_state/controller.dart';
import '../../voice/screen_preview/client.dart';
import '../../voice/screen_preview/uploader.dart';

void initializeScreenSharing(
  ScreenShareController owner,
  ScreenAdaptationOptions options,
) {
  owner.adaptation = ScreenAdaptationRuntime(
    NativeScreenAdaptationPort(owner),
    options,
  );
  owner.metrics = createScreenShareMetricsController(
    owner.api,
    owner.scope,
    readRoom: owner.readRoom,
    isSharing: () => owner.phase == ScreenSharePhase.sharing,
    readQuality: () => owner.quality,
    changed: owner.changed,
    captureObservation: owner.adaptation.collector,
    readTelemetryScope: () => owner.descriptor.telemetryScope(
      owner.api.transport.session.telemetry.snapshot().leaseId,
    ),
  );
  owner.thumbnail = ScreenThumbnailController(
    owner.scope,
    readRoom: owner.readRoom,
    isSharing: () => owner.phase == ScreenSharePhase.sharing,
    thumbnails: owner.thumbnails,
    queue: owner.captureQueue,
    changed: owner.changed,
    previewUploader: LatestScreenPreviewUploader(
      ScreenPreviewClient(owner.api.transport),
    ),
  );
}
