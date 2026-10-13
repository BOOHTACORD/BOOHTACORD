import 'package:boohtacord_desktop/src/features/screen/rollout/native_codec_policy.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/policy.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/publish_plan.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NativeCodecEvidence evidence({
    NativeCodecSupport sender = NativeCodecSupport.supported,
    List<NativeCodecSupport> viewers = const [NativeCodecSupport.supported],
    NativeCodecSupport sfu = NativeCodecSupport.supported,
    NativeCodecSupport vp8Fallback = NativeCodecSupport.supported,
    bool approved = true,
  }) => NativeCodecEvidence(
    senderProfile: sender,
    viewerProfiles: viewers,
    sfuProfile: sfu,
    vp8Fallback: vp8Fallback,
    measuredCohortApproved: approved,
  );

  test(
    'independent compile-time request cannot enable an unapproved cohort',
    () {
      for (final request in ['vp8', 'h264', 'h265', '', 'H264']) {
        expect(nativeScreenDefaultCodec(requestedCodec: request), 'vp8');
        final plan = nativeScreenPublishPlan(
          const ScreenShareQuality(resolution: 1080, frameRate: 60),
          const ScreenMediaRollout(),
          TargetPlatform.macOS,
          requestedCodec: request,
        );
        expect(plan.videoCodec, 'vp8');
        expect(plan.simulcast, false);
        expect(plan.screenShareSimulcastLayers, isEmpty);
        expect(plan.backupVideoCodec.enabled, false);
      }
    },
  );
  test(
    'compatible measured cohort may request H264, not claim confirmation',
    () {
      final decision = decideNativeCodec(evidence: evidence());
      expect(decision.action, NativeCodecAction.requestExperimental);
      expect(decision.codec, 'h264');
      expect(decision.confirmed, false);
      expect(decision.hardwareProven, false);
    },
  );
  test('capabilities alone never approve production H264', () {
    final decision = decideNativeCodec(evidence: evidence(approved: false));
    expect(decision.action, NativeCodecAction.keepBaseline);
    expect(decision.codec, 'vp8');
    expect(decision.reason, NativeCodecReason.cohortNotApproved);
  });
  test('unknown or unsupported sender/viewer/SFU cannot request H264', () {
    for (final support in [
      NativeCodecSupport.unknown,
      NativeCodecSupport.unsupported,
    ]) {
      for (final row in [
        evidence(sender: support),
        evidence(viewers: [support]),
        evidence(sfu: support),
      ]) {
        final decision = decideNativeCodec(evidence: row);
        expect(decision.codec, 'vp8');
        expect(decision.action, NativeCodecAction.keepBaseline);
      }
    }
  });
  test(
    'mixed viewers and absent viewer observations are not a common profile',
    () {
      for (final viewers in [
        <NativeCodecSupport>[],
        [NativeCodecSupport.supported, NativeCodecSupport.unsupported],
      ]) {
        final decision = decideNativeCodec(
          evidence: evidence(viewers: viewers),
        );
        expect(decision.action, NativeCodecAction.keepBaseline);
        expect(decision.codec, 'vp8');
      }
    },
  );
  test(
    'negotiated match alone is confirmed configuration, not hardware proof',
    () {
      final decision = decideNativeCodec(
        evidence: evidence(),
        outcome: NativeCodecOutcome.confirmed,
      );
      expect(decision.action, NativeCodecAction.continueConfirmed);
      expect(decision.codec, 'h264');
      expect(decision.confirmed, true);
      expect(decision.hardwareProven, false);
    },
  );
  test(
    'mismatch/encode/publish failure suggests one validated fallback only',
    () {
      for (final outcome in [
        NativeCodecOutcome.negotiationMismatch,
        NativeCodecOutcome.encodeFailure,
        NativeCodecOutcome.publishFailure,
      ]) {
        final first = decideNativeCodec(evidence: evidence(), outcome: outcome);
        expect(first.action, NativeCodecAction.suggestVp8Fallback);
        expect(first.codec, 'vp8');
        expect(first.confirmed, false);
        expect(
          decideNativeCodec(
            evidence: evidence(),
            outcome: outcome,
            fallbackAttempts: 1,
          ).action,
          NativeCodecAction.stopUnsupported,
        );
        expect(
          decideNativeCodec(
            evidence: evidence(),
            outcome: outcome,
            fallbackAttempts: 8,
          ).action,
          NativeCodecAction.stopUnsupported,
        );
      }
    },
  );
  test('unknown/unsupported fallback is blocked without reconnect advice', () {
    for (final support in [
      NativeCodecSupport.unknown,
      NativeCodecSupport.unsupported,
    ]) {
      final decision = decideNativeCodec(
        evidence: evidence(vp8Fallback: support),
        outcome: NativeCodecOutcome.publishFailure,
      );
      expect(decision.action, NativeCodecAction.stopUnsupported);
      expect(decision.codec, isNull);
    }
  });
  test(
    'failed H264 admission with unknown VP8 support defers all selection',
    () {
      final decision = decideNativeCodec(
        evidence: evidence(
          sender: NativeCodecSupport.unknown,
          vp8Fallback: NativeCodecSupport.unknown,
        ),
      );
      expect(decision.action, NativeCodecAction.defer);
      expect(decision.codec, isNull);
    },
  );
  test('negative fallback count cannot reopen the one-attempt bound', () {
    final decision = decideNativeCodec(
      evidence: evidence(),
      outcome: NativeCodecOutcome.publishFailure,
      fallbackAttempts: -1,
    );
    expect(decision.action, NativeCodecAction.stopUnsupported);
    expect(decision.codec, isNull);
  });
  test('capability evidence takes an immutable viewer snapshot', () {
    final viewers = [NativeCodecSupport.supported];
    final observed = evidence(viewers: viewers);
    viewers[0] = NativeCodecSupport.unsupported;
    expect(
      decideNativeCodec(evidence: observed).action,
      NativeCodecAction.requestExperimental,
    );
    expect(
      () => observed.viewerProfiles.add(NativeCodecSupport.supported),
      throwsUnsupportedError,
    );
  });
}
