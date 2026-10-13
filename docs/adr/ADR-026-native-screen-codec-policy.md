# ADR026: conservative native screen codec policy

Status: accepted for the conservative implementation; H264 rollout deferred.
Date: 2026-10-13. Related issues: #328, #329, #330, #331 and #332.

## Decision

Keep the existing production VP8 baseline and single-layer topology. Backup
encoding remains disabled. `BOOHTACORD_NATIVE_SCREEN_CODEC` is an independent
build-time request: every current value resolves to VP8 because no measured
native H264 cohort has been admitted. It is not a remote kill switch; changing
an admitted build-time policy would require a compatible signed native build.
Capture-engine flags do not implicitly change the codec policy.

The feature-owned native policy separates requested codec, version-scoped
validated profile compatibility, measured cohort approval and actual negotiated
configuration. Advertised H264, a codec name, decoder implementation or a claimed
hardware encoder is insufficient for approval. A future caller must supply
validated sender, SFU and every receiver profile, including packetization/level
constraints, rather than translating any advertised codec name into support.
Missing or mixed viewer evidence cannot admit H264. A newly incompatible viewer
must be explicitly reported unsupported; it must not trigger repeated room-wide
codec changes based on individual samples.

For an experimental publication with negotiation mismatch, encode failure or
publish failure, the executable policy permits at most one *suggested* VP8
fallback when that fallback is validated for all relevant endpoints. Unknown or
unsupported fallback blocks that suggestion; an exhausted/invalid attempt count
stops. The policy performs no publication, reconnect or automatic retry. Any
future application of a suggestion must use the existing serialized publisher
lifecycle, fresh publication generation/descriptor and receiver recovery. Those
runtime fallback paths remain an open acceptance gate; unit tests prove decision
bounds, not physical lifecycle recovery. Voice, microphone and screen audio are
not restarted by this policy.

## Selected, rejected and deferred

| Choice | Decision | Evidence envelope |
| --- | --- | --- |
| Existing VP8 baseline | Selected | Preserves the previous implementation; this is not a new device compatibility admission. |
| H264 constrained-baseline `42e0`, packetization 1 | Deferred | One physical Mac advertises level 52 and cohost Chromium advertises level 31; capability intersection permits only an experiment, not measured improvement or hardware proof. |
| H264 high/other profiles or unknown packetization/level | Rejected by the current experiment guard | No supported measured cohort for those combinations. |
| Arbitrary SDP munging or silently relabelled codec fallback | Rejected | Actual used outbound codec/FMTP must be retained, including rejected attempts. |
| Default backup encoder/additional simulcast layers | Rejected | No measured CPU/uplink budget approving an extra encoder. |
| Global native H264 preference | Deferred | Requires paired stage distributions, readability/latency/voice/audio gates and receiver compatibility. |

The QA experiment uses a guarded private composition overlay of the existing
physical sender harness. Both paired codecs use the same source/capture/vendor
snapshot and differ only in the explicit runtime request. It does not replace
production policy or establish product lifecycle acceptance. It validates actual
sender capabilities, connected SFU codec allowance and all observed viewer
profiles, then reads fresh native sender parameters and the codec actually used
by outbound RTP. A conservative common H264 level is checked without rewriting
SDP. Missing/mismatched codec or an out-of-envelope negotiated FMTP defers the run;
its allowlisted readback receipt is retained instead of inventing a successful
fallback measurement.

The full acceptance matrix requires window/display, 720p60/1080p60/1080p30,
identical controls, alternating order and at least three paired repetitions.
Shorter local pilots are labelled as pilots and cannot close that matrix.
Only this physical Mac is currently available. A cohost headless Chromium
receiver is not physical Mac-to-Mac, Safari or all released native receivers.
Encoder implementation labels remain observations; hardware encoding, GPU and
thermal measurements remain unknown until independently established.

## Verification

Focused native policy fixtures cover approved/unsupported/unknown profiles,
mixed/absent viewers, negotiation mismatch, encode/publish failure, immutable
observations and the one-suggestion bound. Publish-plan tests preserve existing
VP8, bitrate ceilings, maintainFramerate, single-layer and disabled backup for
all platform/profile combinations. QA adapter fixtures cover profile/level
intersection, actual negotiated FMTP, case-insensitive known MIME codec names
and atomic owned allowlisted readback receipts. Device evidence and the final
measured policy conclusion belong in `evidence/qa/issue331-native-codec-2026-10-13.json`.

## Observed local pilot, 2026-10-13

The common physical Mac Debug build ran a controlled 720p60 window prototype
with one cohost headless Chromium receiver, diagnostics enabled and a 4 Mbit/s
ceiling. The current connected SDK reported an explicit VP8/H264 SFU list; the
empty-list override stayed unset and no JoinResponse/fast-connect seam was added.
Both attempts used the same main/vendor/private-overlay bundle and capability
payload. The SHA-bound environment transport preserved sandbox restrictions.

VP8 completed the 30-second warm-up and 60-second steady prototype. Native
accepted-frame median was 57.007 FPS, postprocessed median 56.996 FPS and
encoded/sent median 56.943 FPS. Receiver decoded p05 was 55.666 FPS; headless
video-frame callback p05 was 44 FPS with no callback gap above 500 ms. The
callback statistic is not physical presentation or glass-to-glass latency.
Fresh native readback confirmed 1280×720, configured 60 FPS and one active
encoding with max FPS 60, max bitrate 4,000,000 bit/s and scale-down 1.0.

H264 was actually negotiated, but its readback reported `42e034` (level 52),
packetization mode 1 and level asymmetry 1; the experiment's conservative common
profile was `42e01f:1` (level 31). The guard deferred that attempt and preserved
the actual readback. It did not relax SDP or relabel the attempt VP8. Native and
viewer flow receipts are FAIL for that stopped attempt; there is no accepted
H264 steady window, matched performance comparison or hardware-encoder proof.
This outcome describes this guard/support envelope, not general H264 inability.

Retain production VP8: this pilot provides no admitted H264 performance win or
released receiver cohort. The full repeated window/display/profile matrix,
independent physical receivers, hardware attribution, voice/screen-audio and
latency gates, executed bounded codec fallback/reconnect/rollback and mixed-viewer
runtime behavior remain open. Pure fallback suggestions do not close those
runtime gates. Exact receipts and original-image review are linked by the issue
331 evidence record; earlier capture-path windows use their own immutable source
proofs and are not retagged as this codec comparison.
