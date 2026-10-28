# Production screen binding / real SDK and SFU — I240.C8

**PASS in the exact source/SDK/SFU scope of I240.C8.** Tested source
`072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, Windows11/Node24.18.0,
headless Chromium153.0.8010.12, livekit-client2.22.3, server-SDK2.19.1,
actual existing isolated LiveKit1.13.7. Browser profile27 stages PASS;36 nearest
native tests PASS,0 skips. A controlled negative mutation is killed.
QA240 remains FAIL on134/137/138; implementation140 remains closed.

| What it protects | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
| No screen-video subscription before selection; one selected SFU subscription and renderer | `python -X utf8 .out/qa-screen-preview/start_bridge.py`; `node .out/qa-screen-preview/run_profile.mjs` | Windows/headless Chromium, current production `defaultLiveKitRoomFactory`, real SDK/SFU;2 synthetic publishers | Before exact I240.C8 subscription acceptance | `browser-result.json`, `runtime-audit.json`:27 stages PASS |
| Reselect/unselect/unpublish preserve one current generation and release old tracks | Same browser profile | Actual SDK publications/RemoteVideoTracks, source controller/media binding | Before lifecycle acceptance |25 same-publication reselects add no subscription request; selected/unselected unpublish, republish and3 select/unselect cycles PASS |
| Delayed old events cannot alter B or the new connection | Same browser profile | Actual captured SDK TrackSubscribed events held at consumer delivery, then replayed | Before late-event acceptance | Late A after B and old-room event after fresh connection retain B/one renderer; actual events delivered in both cases |
| Signal reconnect and full disconnect/new factory recover safely | Same browser profile | SDK internal test `signal-reconnect` drives real transport; public disconnect/connect creates fresh real Room | Before reconnect acceptance | SDK signalReconnecting/reconnected observed; B retained; fresh connection starts with2 cards/0 SFU subscriptions |
| The zero-subscription check rejects automatic background subscription | `node .out/qa-screen-preview/run_mutation.mjs` | Same real browser/SDK/SFU; test Vite response changes one registry statement | Before trusting witness sensitivity | `mutation-result.json`: no selection,2 actual SFU subscriptions; original invariant fails; source file unchanged |
| Existing native behavior and SDK prototype boundaries stay executable | Exact argv in `native-runner.json`, cwd `clients/web` | Node24.18.0/Vitest5.0.1, identical pinned dependency tree | Supplemental nearest regression check | `focused-native-result.json`:5 files/36 PASS/0 skips |
| Counts, timers, SFU room cleanup and mutation semantics are checked | `node .out/qa-screen-preview/verify_runtime.mjs` | Retained phase observations and fresh actual SFU management/metrics | Before publishing result | Initialized fresh-viewer gauge0, selected gauge1, final participants/rooms/publications/subscriptions0 |
| Temporary bridge/dev servers are removed and original services remain private/healthy | `python -X utf8 .out/qa-screen-preview/verify_after.py` | Actual Docker/ports/API plus bounded private log scans | After both profiles | Own bridge removed, Vite ports closed,9 original services/restart0, health200 |

## Actual source path and protocol

The existing repository `screen_share_sfu` smoke has its own test viewer and
does not call the production binding. It is not substituted for this acceptance.
This fixture calls the current `defaultLiveKitRoomFactory` unchanged, including
`wireLiveKitRoom` forcing autoSubscribe=false, `bindLiveKitScreenViewer`, real
registry/controller/lifecycle/media attachment and the pinned SDK objects.
Two native synthetic publisher helpers create640×360 canvas streams at a
requested15fps. Publishers never subscribe. No camera, microphone or capture
picker is used; no screenshot, image, recording, frame payload, SDP/candidate
data, room/participant IDs or credentials are exported.

Before selection there are2 discoverable cards,0 desired/subscribed tracks,
0 presented callbacks and no increment in the actual SFU subscribe counter.
The SFU active child-series is initially absent. After it initializes, a fresh
viewer connection with the same2 publications directly observes gauge0 before
any choice. Selected phases settle at gauge1, one SDK subscribed track and one
video element; unselected/unpublished phases settle at0. These are settled
observations, not an assertion about every unsampled transport instant.

An actual A subscription event is held before delivery to the application
consumers. B is selected, then the original event is delivered: B, attach count
and renderer remain unchanged. A second real event is held across full viewer
disconnect; after a fresh factory connects/selects B, its old event is delivered
without changing B. This is controlled callback scheduling at the consumer
boundary, not a claim of naturally delayed packets. The SDK signal reconnect
also uses real signaling; event counts show signalReconnecting1/reconnected1.

The viewer presents47 frame callbacks during the profile. This proves that real
synthetic video was decoded/presented, not physical FPS, latency, image quality,
audibility, media capacity or a performance SLO. All settled source-stack timer
counts are0 for viewer/preview/presence. Their transient attribution peaks are
1/1/0; other timers include SDK, diagnostics and the harness, with one remaining
Vite/SDK/harness timer before browser closure. No general zero-timer claim is made.

## Counterexample and preservation

The mutation changes only a Vite-served test copy of the exact registry statement:
unselected video `setSubscribed(false)` becomes unconditional `setSubscribed(true)`.
The source file on disk retains its original hash. The mutation produces2
subscribed tracks with no choice; the real SFU gauge agrees. The same zero-choice
invariant rejects it. This is a negative fixture, not a product change.

`attempt1/` preserves a setup-only exit1 with0 media stages and own room removal:
reading `livekit-client/package.json` through package exports is blocked.
The dedicated version probe records ERR_PACKAGE_PATH_NOT_EXPORTED. The corrected
runner reads the actual manifest file; the complete browser profile then passes.
Pre-execution hashes bind both attempts and the mutation inputs.

The loopback-only temporary bridge forwards signaling/management and metrics to
the existing owned SFU; RTP/RTCP stay on its existing media ports. The bridge is
removed after both rooms are deleted. Final server gauges for participants,
rooms, published and subscribed tracks are0. Private stateless SDK join grants
expire naturally at their recorded times; explicit JWT revocation is not claimed.
Database counts equal the last prior-packet attestation; there was no fresh SQL
pre-snapshot in this SDK-only packet, and no Go-auth/voice-lease proof is claimed.

`source-binding.json` records exact source/test/lock hashes, the actually resolved
browser SDK entry digest, image/version, and comparison with fresh master.
Public LF copies are sealed separately from original working-byte hashes.
The ignored dependency junction points to an already installed tree with
identical package/lock content. A fresh privately provisioned packet is required
for replay; guards prevent overwriting existing receipts.

This is Vite-served source-module integration through the actual factory,
not a built/deployed Web-bundle, packaged/native/physical or production-UI gate.
Direct owned SDK grants use supported generic identities; Go authorization and
lease-bound presence/JPEG-preview paths remain separate. The stopped production
picker/receiver flow is not resumed.43 consolidation decisions remain untouched.
