# Issue579: bounded recovery without a subscribed video track

Packet: small_direct implementation after a qualified review_gate counterexample.
Route: Flutter voice viewer pending presentation; composition edges are
voice_room/build/ended_screen and screens/voice_screen_ended.dart.
Backlog: FV2-003; preserve FV2-009/010/011/012/013, T-022/030/051 dependencies.

The existing controller bounds automatic subscription recovery, but the
still-published/no-track fallback ignores exhaustion and renders an indefinite
connecting label. The real production fallback fails a widget counterexample
after30 virtual seconds while the controller explicitly reports exhaustion.
This is a confirmed presentation defect; the shipping Windows first-frame
failure and its transport/codec cause still require physical acceptance.

1. Retain focused RED through the production fallback, not a copied renderer.
2. Add one child leaf for pending status and current-publication retry policy.
3. Wire existing exhausted/current controller state and guarded manual retry.
4. Preserve normal connecting, genuinely ended streams, choices, participants,
   renderer ownership, subscriptions, microphone and voice lease behavior.
5. Test exhausted, initial, stale/replaced publication and ended states;
   verify explicit retry callback and narrow/desktop presentation.
6. Run nearest native tests, targeted analysis and feature/parity policies.
7. Register the scenario and retain source/log hashes and honest limitations.

Ratchet: target100/hard120 lines per changed production/test file;
target8/hard16 production files/direct tests per leaf. No new global capture
filenames or screenshot baseline approvals. No requirements/contract changes.

Native: Flutter3.47.7/Dart3.13.5, flutter test --no-pub targeted viewer tests;
flutter analyze --no-pub --no-fatal-infos exact files; repository feature gates.
Stop: tested source/evidence handoff to release_closure; root resumes physical
phone/PC testing. Hosted CI/merge/artifacts belong to that agent. #579 remains
OPEN until its source-bound paired physical criteria pass. macOS/iOS media,
audibility and43 consolidation decisions remain outside this packet.
