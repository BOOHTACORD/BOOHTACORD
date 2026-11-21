# Web push-to-talk — 2026-11-21

Baseline and public Web receipt: `b046c18daae89ec4d66135f856fd8fc59b867ba6`.
The feature is present in audio settings: select «По нажатию» and assign a key.
The approved brief requires an active page, excludes editing/modal targets and
releases PTT on focus loss/disconnect; global hotkeys are outside that contract.

## Actual defects and repair

An unchanged baseline built against the owned API/SFU reproduced two failures:
explicit listener rejoin did not arm PTT; releasing the key during deafen could
restore an open microphone on undeafen. Ordinary hold/release worked. Closing
settings left BODY focus, so an alleged settings focus trap was not reproduced.

PTT now arms both successful join choices, belongs to its activation owner and
resets held inputs on room/connection transitions. Queued actions cannot unmute
a replacement room. PTT reconnect admission is listener-only, independent of
the old microphone's publishing state; a fresh key press is required.

Explicit mute cancels the deafen restore intent, including while its server
request is pending. This latter race was reproduced in the actual browser after
the first repair and added as a separate RED/GREEN regression. Ordinary VAD
deafen restoration remains covered and preserved. Keyboard auto-repeat cannot
reopen a released microphone after focus/recovery reset. Protected editing and
modal targets, AFK/permission checks and existing touch behavior are retained.

## Observed acceptance

`python -m tools.qa.push_to_talk.run --output .out/ptt-actual6` — PASS.
Actual production Web bundle, independent authenticated browser contexts and
owned Go/PostgreSQL/LiveKit/Caddy services; synthetic WAV input, no user recording.
All 26 remote decoded-audio checkpoints passed: held signal, release silence,
editing/modal exclusion, pending deafen release, listener rejoin, actual headed
window focus loss and repeat suppression, owned SFU stop/restart and fresh-key
recovery, trusted emulated touch hold/capture/release/cancel. Positive RMS ranged
approximately 0.076–0.089; all four samples at each silent checkpoint were zero.
Source stability PASS; owned containers/networks/images were removed.

`npm test -- --run` — 592 files / 2047 tests PASS.
Focused Web regression selection — 11 files / 38 tests PASS; original failures
were observed before implementation. Owned SFU-control boundary — 2 tests PASS.
Production `vue-tsc`/Vite build and OpenAPI contract verification PASS.
`python -m tools.ci.native.contracts` — PASS on the final source in an owned
Linux checkout: 1813 Python tests (27 existing platform/optional skips), then
contract, traceability, workflow, SBOM, topology and Compose verifiers passed.
The earlier trial selector mapping failed its pinned network artifact check;
that mapping was discarded and the final selector remains unchanged.

Registered Web acceptance completed for voice/idle_afk/shell/auth/chat/
connection_status/screen: 31 stages PASS, including real-stack 1440/393px and
source stability. Overall BLOCKED: `screen_profile` has one unchanged conditional
publisher/viewer baseline skip (isolated tokens required), with 19 tests PASS.
The 896 broad-regression captures remain NOT_RUN for full visual review; only
the seven PTT-specific captures are accepted here. No broader visual gate closes.
The canonical checkout retained the discarded selector trial; a separate hash
comparison confirms all 16 final production/runner files match both Linux
checkouts and the actual PTT run. Final unchanged-selector contracts passed in
the separate checkout; no superseded routing metadata is claimed accepted.

Seven source-size PNGs were inspected: assigned key, held, released, undeafened,
recovered, touch held/released. Mode/key labels are legible; participant state
changes correctly; mobile hold control remains reachable. No baseline changed.
Failed diagnostic/setup attempts remain in `.out/ptt-actual1` through `5`; the
successful result does not relabel them. See the JSON companion for provenance,
per-checkpoint measurements, original source identity and capture hashes.

The final documentation/registry differ from the runtime worktree fingerprint;
production and runner hashes bind the tested implementation explicitly.
Cross-browser Safari/Firefox, physical Android and human audibility are NOT_RUN.
This establishes transport and silence behavior, not perceptual sound quality.
No production fix deployment is claimed.
