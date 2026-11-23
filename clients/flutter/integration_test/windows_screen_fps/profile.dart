import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'pair.dart';
import 'sample.dart';
import 'sfu_pair.dart';

Future<Map<String, dynamic>> probeProfile(
  rtc.DesktopCapturerSource source,
  int fps,
) async {
  final quality = ScreenShareQuality(resolution: 720, frameRate: fps);
  final track = await LocalVideoTrack.createScreenShareTrack(
    ScreenShareCaptureOptions(
      sourceId: source.id,
      maxFrameRate: fps.toDouble(),
      params: quality.parameters,
    ),
  );
  FpsPair? pair;
  try {
    pair = await FpsPair.create(
      track.mediaStreamTrack,
      track.mediaStream,
      quality.parameters.encoding!.toRTCRtpEncoding(),
    );
    return {...await measure(pair, fps), 'transport': 'direct-peer'};
  } finally {
    await pair?.close();
    await track.stop();
  }
}

Future<void> probeSfuSequence(
  rtc.DesktopCapturerSource source,
  String url,
  Future<void> Function(Map<String, dynamic>) report,
) async {
  const low = ScreenShareQuality(resolution: 720, frameRate: 15);
  final track = await LocalVideoTrack.createScreenShareTrack(
    ScreenShareCaptureOptions(
      sourceId: source.id,
      maxFrameRate: 15,
      params: low.parameters,
    ),
  );
  SfuFpsPair? pair;
  try {
    pair = await SfuFpsPair.create(track, low, url);
    const profiles = [15, 30, 60, 15];
    for (var index = 0; index < profiles.length; index++) {
      final fps = profiles[index];
      if (index > 0) {
        await pair.changeProfile(
          ScreenShareQuality(resolution: 720, frameRate: fps),
        );
      }
      final sample = await pair.measure(fps);
      await report({
        ...sample,
        'transport': 'livekit',
        'controller_restart': index > 0,
        'room_connected':
            pair.publisher.connectionState == ConnectionState.connected,
      });
    }
  } finally {
    await pair?.close();
    await track.stop();
  }
}
