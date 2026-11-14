# Verified client publications and catalog candidate

Scope: publish the owner's accepted current implementation, including the
Android RNNoise state ABI correction. This does not close the full issue #687
acoustic, automatic adaptation or physical-device acceptance gates.

## Immutable publications

| Platform | Version/build/order | Exact source | Release run |
| --- | --- | --- | --- |
| Windows x64 | 1.0.55 / 91 / 70 | a1c1b7c5417981fcd8d8a8e45384594556e1b11f | 43640099640 |
| macOS universal | 1.0.55 / 91 / 70 | a1c1b7c5417981fcd8d8a8e45384594556e1b11f | 43642078146 |
| Android three ABIs | 1.0.56 / 92 / 71 | 7448cda09939a58c3982aafa836b178adca4a75a | 43650833696 |

All three release workflows completed successfully. Public, unauthenticated
downloads were verified independently against fresh GitHub release metadata,
asset sizes/digests, exact source identities, complete manifests, checksums and
native asset validation: Windows six assets, macOS six, Android seven.
Windows contract bytes use the original Windows checkout; macOS and Android
were checked against canonical Git LF bytes. All 22 macOS contract hashes also
matched their exact source Git blobs. Windows remains unsigned; macOS is ad-hoc
signed and not notarized. No stronger signing assurance is claimed.

Android apksigner independently verified all three downloaded APKs with signer
SHA256 394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b.
On disposable API35 x86_64 emulator-5560, the public signed APK upgraded from
1.0.55 (4091) to 1.0.56 (4092) with adb install -r. First-install time remained
unchanged. Cold launch succeeded, the process remained alive, and the reviewed
1080x1920 capture showed the complete login screen and version 1.0.56 (92).
No microphone permission, speech capture or user session was used.

The RNNoise Java/native failure-before and JNI pass-after evidence is in
android-rnnoise-state-abi-2026-11-15.md under evidence/noise-suppression.
Android 1.0.55 is preserved as a prerelease and excluded from this catalog.

## Catalog candidate and checks

PR #795 merged the independently verified Windows promotion after successful
exact-candidate CI 43649182882 and required PR CI 43650762367. The protected
promotion helper's PR-creation step failed; the maintainer opened the exact
two-file, immutable-intent candidate with its verified CI marker. Retrying only
failed jobs cannot recover its attempt-scoped input artifact. Those helper runs
are not represented as passing. Branch protection and required checks remained.

This candidate uses catalog compare-and-swap 34 -> 40 for Android arm64/armv7/x64,
macOS arm64/x64 and Web. The Windows target is byte-for-byte structurally
unchanged. Web is 1.0.55/browser-stable-r63, already independently observed on
production source a1c1b7c5417981fcd8d8a8e45384594556e1b11f after successful
delivery run 43639497262, including source receipt, build hash, health, protected
endpoint and a fresh anonymous browser login without page errors.

The old catalog test failed before edits because it asserted revision 29
against master revision 33. It now checks Windows identity, versioned download
URL, action and architecture consistency rather than freezing a release number.
All 21 client-update tests and native catalog validation passed after edits.
Final production rollout/readback is separate; its actual receipt and live
catalog results must be linked from the PR and issue after deployment.

Physical Android speech/AEC/AGC, installed-old Windows update UI and macOS
Gatekeeper acceptance remain NOT_RUN. The earlier canonical real-stack check
remains FAIL/BLOCKED for unavailable local Linux Docker, as recorded in the
RNNoise evidence; it is not a passing native media gate.
