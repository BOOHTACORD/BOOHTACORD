# DW-010 / #349 — Web mini-player

Date: 2026-10-17 (Europe/Istanbul). Parent: #339. Web only; #247 and #173 native/hardware gates remain separate.

## Interaction and layout decision

The pinned viewer reserves a strip at the top of the main workspace, before TEXT/DM or settings. It does not occupy the member rail, composer or voice dock. The member rail keeps its independent scroll. The scripted UX tasks are: follow the stream, type/send in TEXT and DM, find the last member, expand and return. They are exercised by production Vue components and an actual owned API/SFU journey; this is bounded task evaluation, not participant research.

Pin is opt-in. Unpinned navigation still closes the viewer. A pinned viewer keeps the same video/audio elements when moved through the dock or full-area view. Unpin returns to voice and removes the pin while retaining playback; the next navigation then follows the ordinary unpinned policy. Close releases the selected receiver while the voice session remains connected. Escape returns an expanded viewer to its previous dock and restores keyboard focus.

Pause stops local video presentation only, retaining the subscription and stream sound; mute is separate and respects deafen. A deliberate local pause suppresses receiver health reporting and automatic recovery until resumed. Full view also exposes resume. Missing audio and ended streams have explicit disabled controls, while close stays available. A short viewport uses a 52px dock with five visible 44px controls; normal mobile uses two rows. This reserves input space without a floating overlap.

## Before / After

The private original tour frames 41/53 are unavailable here (`NOT_RUN` for pixel comparison). Before reproductions on exact master `979d0bd0631e1be9fda8071f648c16220fc32278` show that navigating to TEXT/DM removed the pinned viewer: selected-channel voice admission was incorrectly used as the viewer mount condition. After retains it in a reserved strip. Source-sized selected captures and hashes are recorded in the final evidence receipt; generated media stays outside Git.

## Acceptance

Focused tests were written before implementation: the expansion state regression failed on master, and the production WorkspaceMain fixture reproduced the navigation teardown. The new 16-case browser suite covers 320/390/1024/1440px, 100/200% root text, independently measured native browser zoom at 200%, keyboard, touch with reduced viewport height, ended/no-audio/deafen states, roster scroll and media element identity. The actual two-client journey also checks SFU subscription counts, per-stream volume, TEXT/DM send, local pause with audio retained, mute, expand/unpin, explicit stop and pinned logout cleanup.

Initial clean full gate: `beea54068b571fcbff38ccbc2fe0531846180e99`, `.out/local-features/20261017-083105` — **23/25 raw stages PASS** (unit suite, build and all21 browser configurations). Raw `FAIL` and `visual_review: NOT_RUN` remain unchanged. Desktop passed the new feature assertions, then the existing20-second lease-notification wait timed out with one pending kick and no connected transports. Touch hit a test-locator defect: its role query excluded the CSS-hidden retained volume input.

Accepted clean source: `566395007a9e26d795b1f1c4debe4508721ed8e4`. Its sole delta from the full-gate source is that volume locator (`includeHidden: true`) and an explanatory comment in the integration harness. Application code, component/browser tests, backend and build configuration are byte-identical. Both complete actual API/SFU stages were rerun on this exact clean source and passed. Each has before/after source and log hashes in the JSON companion. The combined result is **PASS_AFTER_HARNESS_FIX_AND_TARGETED_RERUN**, with the original failures preserved; no timeout, ACL, production behavior or media guard was relaxed. Fresh CI and merge/closure receipts are linked in the PR.

Separate selected source-sized visual review is PASS; all 11 selected final fixture frames match the full-gate hashes. Exact-master TEXT and DM Before reproductions are retained. The actual final runs preserve the same video/audio elements, stream/track objects and connected peers through TEXT/DM, expand/Escape and unpin without extra subscription requests. The existing per-stream volume remains65%; local video pause keeps audio playing. Mute/resume act on the actual output. Stop unsubscribes the two selected publications exactly once. Pinned logout detaches both outputs and closes old peer connections. On mobile, the volume check observes retained mixer state via its existing hidden range; it does not claim a mobile volume-adjustment UI.

Source stop, disconnect, logout/account switch and account revoke also passed the existing nine-case Web mini-player suite before the final CSS-only header bound. Its original source/build manifests remain in the local runtime receipt. The legacy runner now validates its own exact4830 origin, enters disposable credentials once, and honors its child Docker context. Native #247 acceptance remains open. Intermediate experiments and expected tests before fixes remain under `.out/issue349/`.

The immediate mobile runtime captures also contain the existing transient screen-start notice over the composer. They are transport/state observations, not approved layout baselines; the stable source-identical component frames and geometric checks establish the mini-player boundaries. Other existing notification overlays are outside this leaf.

## Limits

Only the OS capture boundary is synthetic canvas plus a quiet oscillator. The Go API, secure-cookie session, LiveKit publication/subscription and browser decoding are actual. No production mutation, native-client acceptance, physical keyboard/IME/picker, screen-reader research, hardware audio/capture, 60 FPS, media QoE or capacity claim is made. The approved Windows product brief is unavailable; the traceability verifier can check the repository index only.
