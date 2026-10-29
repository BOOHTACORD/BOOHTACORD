# Android landscape composer acceptance — #582

Execute inline. Route class: split_first. Preserve the existing portrait and
desktop presentations, conversation/session state and normal voice controls.

The physical signed2083/sourcef370 baseline reproduces overlapping Send/Leave
with a recovering realtime banner, active SHARE_TEST voice and native Gboard.
Observed visible overlap5166px²; composer is hidden in the source-sized image.
The owned18-character draft survived rotation/hiding IME, then was cleared;
rotation1/0 and initial idle voice were restored. No message was sent by baseline.

1. Add a full WorkspaceScreen widget regression in
   `clients/flutter/test/features/workspace/short_viewport/widget_test.dart`.
   Match Samsung2340×1080, DPR2.8125, top84px and IME605px, recovering banner,
   connected voice and a normal two-participant DM. Require visible/hit-testable
   Send/Leave with disjoint rectangles, no overflow and retained draft/selection.
2. Keep one short-native-editing policy in
   `clients/flutter/lib/src/features/workspace/short_viewport/` and typed tests.
   Below the available height needed for normal stacked controls, show recovery
   and voice controls on single rows and prioritize the active DM composer.
   Reuse actual voice actions, labels, warning text and secure send callbacks.
   Preserve support notices, queued attachments/reply context and larger views.
3. Follow exact native edges in realtime lifecycle/status, voice_dock/build and
   direct_conversation/build. Split an edited handler if needed to stay≤120lines.
   Run the focused RED before implementation, then nearest native checks and
   register the scenario in local_features/features.json.
4. Delegate PR/CI/signed Android candidate handling to the release agent after
   focused GREEN. Require the approved certificate and post-install APK hash,
   preserving session/permissions with ordinary replacement install.
5. Repeat the physical DM/voice/Gboard scenario on fixed signed source. Require
   actual visible Send publication and PC peer rendering, unchanged voice
   membership, draft/selection over hide/show IME and both orientations, then
   delete the fixture and restore initial device state. Keep other variants and
   unavailable platform/media gates explicit; no43 consolidation decisions.

Stop condition: issue582 closure evidence includes executed regression,
final-source CI and signed physical positive acceptance. Screenshots/component
tests alone cannot prove native hit-testing, receipt on PC, or media quality.
