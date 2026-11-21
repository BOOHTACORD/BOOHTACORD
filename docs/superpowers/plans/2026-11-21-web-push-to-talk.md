# Web push-to-talk acceptance and repair plan

Execute inline in this chat; preserve the user's running Windows client and phone.

**Goal:** Verify current Web PTT from user input through actual microphone media,
repair reproduced failures and deliver focused source/runtime evidence.
**Architecture:** Existing activation_store -> activation/ptt -> PushToTalk ->
voice connection/session. Browser-active-page keys only; never global hotkeys.
**Stack:** Vue/Pinia, Vitest/Playwright, owned Go/PostgreSQL/LiveKit/Caddy.

## Operating brief

- workflow_class=split_first; task_size=medium; structure_mode=structure_no_rg.
- Baseline master b046c18daae89ec4d66135f856fd8fc59b867ba6.
- Route: Web voice/activation keyboard and current-room PTT ownership.
- Existing task T-022; dependencies T-006 and T-020 read. Approved brief lines
  154/162: active-page only, editable/modal exclusion, release on loss/disconnect.
- Preserve VAD default, permission/AFK/deafen guards, unrelated microphone and
  deafen shortcuts, touch hold semantics and existing account isolation.
- Production: voice/activation/ptt.ts, voice/push_to_talk.ts, workspace/voice_join/action.ts,
  voice/{connection_lifecycle,microphone_controls,voice_session_controls,voice_session_types}.ts.
  Tests: activation/{deafen_release,lifecycle,recovery_policy}.spec.ts,
  workspace/voice_join/ptt.spec.ts and voice/push_to_talk.spec.ts.
  QA: tools/qa/push_to_talk; registry acceptance/parity and evidence companions.
- Native checks: nearest Vitest tests, production vue-tsc/Vite build, actual
  two-browser media test, registered Web feature acceptance, contracts/preflight.
- Limits: target100/hard120 lines; leaf target8/hard16 production/direct tests.
- Stop: actual input/remote-media matrix passes, found defects have RED/GREEN
  regressions, source/evidence reviewed and PR prepared; no deployment inferred.

## 1. Preservation and current behavior

- [x] Read current owners/import edges and product contract; baseline11 focused
  tests PASS. They cover generic key edges and touch, not real desktop media.
- [x] Read production receipt without authentication: served revision b046c18.
- [x] Build unchanged master and open real Web against an isolated owned stack.
- [x] Select PTT, assign KeyV, close settings and test actual focus left by UI.
  Compare holding with ordinary workspace focus, editing and modal focus.
- [x] Observe local mute and received synthetic audio during idle/held/released,
  blur, page hide, repeat and deafen transitions. Never record user audio.
- [x] Leave/rejoin and interrupt/recover the owned room while a key is held;
  require muted replacement room and a fresh press to speak.

## 2. Reproduced defects only

- [x] Add focused failing behavior tests for each reproduced owner/input failure.
  Preserve original11 tests and intentional protected-target behavior.
- [x] Correct activation lifecycle/current-room ownership and keyboard release
  only where a failing test and actual reproduction establish the defect.
- [x] Keep assignment usable without widening editing/modal or global capture.
- [x] Re-run RED cases GREEN and exact two-browser media cases on fixed source.
- [x] Register exact PTT scenario/parity decisions in local_features/features.json
  and explicit product-map leaf ownership if paths are introduced/moved.

## 3. Evidence and delivery

- [x] Inspect original-size settings/held/released/recovered browser captures.
- [x] Record source/bundle, sender/receiver measurements, failed attempts and
  cleanup in evidence; distinguish transport gates from perceived audio quality.
- [x] Run nearest/full applicable unit/build, registered Web real-stack checks
  and mandatory preflight/manual review before each commit. Keep unavailable
  physical/native checks separate; do not claim deployed/released/merged states.
- [x] Prepare a ready PR with concise problem, resulting behavior and validation.

Delivery packet: retain the existing conservative CI selector for the new QA
leaf; its unknown path expands all gates rather than weakening native/server
checks. A trial narrow selector rule was discarded after the repository artifact
verifier identified its additional network-evidence obligation. No delivery or
network verifier change belongs to this Web PTT repair. The original failed
contract attempt is retained; rerun the final unchanged selector separately.
