# DW-009 / GitHub #348 — Web screen share setup and diagnostics

Base: `1784d2cd209e0a4d23efd5a77300d1b92c571bcf` (merged DW-008). One leaf; dependencies T-022, T-050, DW-003/004/008 read. Web Vue production components only; no backend, ACL, capture protocol, media engine, preset catalogue or native changes.

## Change and acceptance scope

The launch dialog keeps scenario, resolution/FPS, selected profile and Start/Cancel primary. The duplicate recommendation/apply action and repeated large heading are removed; capabilities, bandwidth ceilings and technical details are collapsed. The visible disclaimer distinguishes a target from measured output. The browser owns source selection. Unsupported capture has a visible alert before controls and cannot start. Quality changes retain the existing sender update path.

Sender status distinguishes active/ended/unknown and selected from measured output. Missing target stays unknown; measured zero FPS stays zero. Receiver statistics show selected, confirmation and measured output first, with technical rows collapsed, an explicit content-free clipboard action, visible copy failure, Escape/focus return and reachable mobile keyboard controls. The existing diagnostic JSON export remains available in its own disclosure.

The actual publisher wraps browser failures. A new test first reproduced loss of NotAllowedError; feedback now unwraps bounded publisher-operation errors without exposing exception text or hiding cleanup failures. No capture/publication/lifecycle semantics change.

## Test-first observations

- Three initial browser tests failed on duplicate recommendation/technical hierarchy, unsupported Start, and fabricated sender target.
- Source-resolution inspection found heading/Cancel clipping at 320px with 200% text. A new geometry assertion reproduced it before the CSS repair; the final layout wraps the title and stacks footer actions. Unsupported guidance precedes quality controls. Narrow statistics use stacked label/value rows.
- The first actual API/SFU run reproduced generic permission feedback. A focused unit test failed before the fix. Later exploratory runs corrected the acceptance harness's assumption that configuration must already be confirmed, and its incorrectly scoped relative locator; raw failures are retained under `.out/issue348/`.
- Focused checks: 1556 Web unit tests; 20 new browser cases, 72 accessibility scans at 320/390/1024/1440 ×100/200% text; real browser 200% zoom at outer widths 640/780/2048/2880; touch disclosure/cancel. Existing screen-profile suite: 18 PASS; one pre-existing credential-gated baseline NOT_RUN. Existing accessibility suites: 110 +1 PASS after updating obsolete copy assertions. Build PASS with existing bundle/dynamic-import warnings. Traceability PASS for 39 committed requirements (approved Windows brief unavailable; index-only).

## Visual review

Before captures use exact base source and the same synthetic fixture at 390/1440. The original private tour 33–40/52 was unavailable and is NOT_RUN, not a pixel reference. No baseline approved. Selected frames are reviewed at source resolution; large browser-zoom frames use exact crops. Closed/open technical content, current selection versus 1920×654/1 FPS, unsupported guidance, large text, fixed reachable footer and mobile sheet are reviewed separately. A focus tooltip over the header is existing keyboard-help behavior; scroll-body boundary clipping in enlarged text is intentional scrolling, while title/actions remain within the viewport. No screenshot proves media quality.

A final boundary test also reproduced a desktop popover leaving the viewport when clipboard failure feedback increased its height. Repositioning now runs after either copy result; the failure and repair are retained in focused evidence.

## Final source-bound gate

Clean accepted source: `fc08c8766324e3a717a8b950209081391b436217`. Run `.out/local-features/20261017-000830`: **23/24 stages PASS**, with only the existing lease-notification wait failing at 1440. A source-bound rerun of that complete actual-stack stage passed on the identical clean commit (receipt in JSON); all 24 stages are verified **PASS_AFTER_TARGETED_RETRY**. The raw runner remains `FAIL`; selected-frame review is separately PASS; the original failure is not overwritten. All 19 reviewed final fixture frames match the gate hashes exactly. Eight Before frames, an additional source-sized copy-failure frame and two exact zoom crops were also reviewed; actual desktop/mobile statistics are reviewed separately. Machine-readable evidence: `dw09-screen-share-ui-2026-10-16.json`.

Earlier full run `20261016-234713` remains FAIL (21/24 PASS): two obsolete immediate-visibility/copy assertions and the existing 15-second outbox worker / 20-second notification wait. Both UI tests now assert collapsed→expanded data, and legacy SDK track-name coverage is also run in CI. No timeout, assertion or media guard was weakened. Raw failed experiments remain under `.out/issue348/`.

Both final actual runs passed cancel→denied→retry/publish→decode→stop, three transient-user-activated capture requests, stopped source track and retained voice. They received no configuration acknowledgement and displayed that explicitly; a 640×360 synthetic source was never labeled 720p/30 FPS output. Metadata fixtures independently cover confirmed/pending/ended/missing configurations. No transport metadata change is claimed. The intermediate clean run 463c4282 passed 24/24 before the final copy-feedback placement regression was added and repaired. The final source is rechecked in full. Fresh CI and final merge/closure receipts are linked in the PR.

## Explicit limits

Physical Chrome system picker/permissions, macOS native capture, Android/iOS/Windows, native screen readers, system/game audio, 1080p60 QoE, capacity and paired physical-device acceptance: NOT_RUN. The owned-stack source is a synthetic canvas at the OS-picker boundary; API admission, SFU publication, subscription, decoding and stop are real. Neither a preset nor a static/low-FPS synthetic frame is a quality/capacity PASS. Related media/native gates remain independent.
