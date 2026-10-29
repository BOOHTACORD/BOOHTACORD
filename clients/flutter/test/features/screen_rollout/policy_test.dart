import 'package:boohtacord_desktop/src/features/screen/rollout/policy.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/publish_plan.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/client.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/uploader.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/receive_state.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native conservative defaults keep JPEG but single layer on every platform', () {
    const flags = ScreenMediaRollout();
    expect(flags.jpegPreview, true); expect(flags.boundedSimulcast, false);
    for (final platform in TargetPlatform.values) {
      expect(nativeScreenPublishPlan(ScreenShareQuality.desktopDefault, flags, platform).simulcast, false);
    }
  });
  test('native desktop opt-in bounds two VP8 layers and Android remains single layer', () {
    const flags = ScreenMediaRollout(boundedSimulcast: true);
    final plan = nativeScreenPublishPlan(ScreenShareQuality.desktopDefault, flags, TargetPlatform.windows);
    expect(plan.simulcast, true); expect(plan.videoCodec, 'vp8');
    expect(plan.screenShareSimulcastLayers, hasLength(1));
    expect(plan.screenShareSimulcastLayers.single.encoding!.maxFramerate, 15);
    expect(plan.backupVideoCodec.enabled, false);
    expect(nativeScreenPublishPlan(ScreenShareQuality.desktopDefault, flags, TargetPlatform.android).simulcast, false);
  });
  test('disabled native JPEG uploader cannot create generations or requests', () async {
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async { requests++; throw StateError('must not request'); }));
    final sender = LatestScreenPreviewUploader(ScreenPreviewClient(api.transport), enabled: false);
    await sender.start('11111111-1111-4111-8111-111111111111');
    await sender.stop(); expect(requests, 0);
  });
  test('disabled reader rejects hints before accessing the Room or transport', () {
    final receiver = ScreenPreviewReceiver(_ForbiddenOwner(), enabled: false);
    receiver.updated('lease', 'generation', 1);
    expect(receiver.states, isEmpty);
  });
}

class _ForbiddenOwner implements VoiceController {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Room/HTTP must remain untouched');
}
