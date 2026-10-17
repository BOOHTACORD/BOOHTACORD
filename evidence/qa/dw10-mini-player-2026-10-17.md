# DW-010 / #349 — Web mini-player

Date: 2026-10-17 (Europe/Istanbul). Parent: #339. Web only. Native/hardware #247 and #173 gates remain separate.

## Interaction decision

The pinned viewer reserves a strip above TEXT/DM or settings inside the main workspace. It does not occupy the member rail, composer or voice dock. The member rail keeps its independent scroll; the chat header stays within its own width. The scripted UX tasks are watching, typing/sending in TEXT and DM, finding the last member, expanding and returning. This is bounded task evaluation, not participant research.

Pin is opt-in. Unpinned navigation closes the receiver. Unpin returns to the active voice room, retains playback and removes the pin. The next navigation follows the ordinary unpinned policy. Selecting a different voice room closes the old viewer and presents that room's prejoin controls while the original voice connection remains in the dock; the pin never presents an old screen under another room's heading. A focused regression failed before this final guard was added.

Pause affects local video presentation only; sound is separately controlled and deafen is respected. Deliberate pause suppresses receiver health reports and automatic recovery. Resume is available in full view. Expand/Escape keeps the same viewer and returns keyboard focus. Ended/no-audio controls are explicit; close stays available. Normal mobile uses two control rows; short viewports use a 52px dock with five 44px targets.

## Before / After and verification

Original private tour pixels 41/53 are unavailable (`NOT_RUN` for pixel comparison). Exact master `979d0bd0631e1be9fda8071f648c16220fc32278` was reproduced with the production WorkspaceMain fixture: the pinned viewer disappeared on TEXT and DM navigation. After retains the same video/audio elements in the reserved strip. Before TEXT/DM320/1440 and selected After frames were inspected at source resolution; all 11 selected final fixture frames match the full-gate hashes. Exact actual desktop/touch and native-browser-zoom crops were reviewed separately. No screenshot baseline was approved.

Clean accepted source: `adfea086b233944c542c5b595b0776ce14e6cff1`. Full registered Web gate `.out/local-features/20261017-085309`: **25/25 raw stages PASS; raw REVIEW_REQUIRED remains unchanged with visual_review NOT_RUN. Separate selected-frame manual review is PASS.** Combined verification: **PASS**. The JSON companion binds each changed source/test file, raw report, actual report and selected capture. Fresh CI and final merge/closure receipts are linked in the PR.

The complete unit suite has 1557 tests in 473 files. All 21 registered browser configurations ran; the new mini-player suite has 17 cases at 320/390/1024/1440px,100/200% text, independently measured actual 200% browser zoom, keyboard, touch/reduced height, deafen/no-audio/ended, independent roster scroll, different-voice prejoin and media-element identity. Traceability passes 39 repository-index requirements; the approved Windows brief is unavailable on this host.

Actual final API/SFU journeys at desktop 1440 and touch 393 verify TEXT/DM sending, the same video/audio elements and stream/track/connected-peer objects, and no extra subscriptions during navigation/expand/unpin. Per-stream volume remains 65%; local video pause keeps audio playing. Mute/resume affect the actual output. Stop unsubscribes the two selected publications exactly once; pinned logout detaches both outputs and closes old peers. The mobile volume assertion observes the existing hidden retained range; it does not claim a mobile volume-adjustment UI.

The first full attempt remains FAIL 23/25: the existing desktop notification wait and a hidden mobile range locator. After the locator fix, both full actual stages passed. That attempt was then superseded when final review found the different-voice presentation regression; its failing test, source and original reports are retained. The final application guard is verified by a new full gate, not inferred from the earlier run. Legacy nine-case actual Web mini-player lifecycle checks (source removal, disconnect, logout/account switch and revoke) also passed before the final CSS/voice-room guards, with original source/build manifests retained. The legacy QA runner validates its own exact 4830 origin and honors its caller Docker context.

## Limits

Only the OS capture boundary is synthetic canvas plus a quiet oscillator; Go admission, secure-cookie session, LiveKit publication/subscription and browser decoding are actual. Immediate mobile runtime captures contain an existing transient screen-start notice over the composer; they are state/transport observations, not layout baselines. Stable mini-player boundaries are established by source-identical component frames and geometry. Other existing notification overlays are outside this leaf.

No production mutation, native-client runtime, physical picker/IME/screen-reader study, hardware capture/system audio, 60 FPS, QoE or capacity acceptance is claimed. Selected settings and decoded output remain distinct; unknown sender configuration remains unknown.
