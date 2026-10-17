# DW-14 — web-tour regression bridge

State: **PASS_SCOPED; registered automated acceptance PASS; full visual review remains REVIEW_REQUIRED**. Current source is master `25be6ecac1a404469833da284f6d1ce70a350a47` (17 October 2026). The 15 October production tour displayed Web 1.0.32 / r-stable-r46; its deployed SHA is unverified, so it is a historical observation rather than a source-equivalent baseline.

The local tour contains 55 available frames. The source images include account and conversation data and remain private; this report publishes no images, user names, DM text, or screenshot hashes. Missing IDs are 47, 54 and 55. Each frame below is mapped by sanitized state, viewport, UI owner and treatment.

## Frame inventory

| Frame | Viewport | Sanitized state | Primary UI owner | Expected change / assessment | Status |
|---:|---:|---|---|---|---|
| 01 | 3440×1315 | TEXT channel conversation | conversation / message history | #345 and #352: preserve message rhythm, draft, scroll anchor and header actions; no residual layout defect. | PASS_SCOPED |
| 02 | 3440×1315 | Workspace menu | workspace navigation | #344: compact navigable rows and one scroll owner; preserve open/close behavior. | PASS_SCOPED |
| 03 | 3440×1315 | Guild settings | admin guild settings | #342: consistent primary action and native field; current control matrix covers the same production surface. | PASS_SCOPED |
| 04 | 3440×1315 | Role administration | admin role editor | No tour-specific regression recorded; permission controls stay under existing ACL/admin tests. | PASS_SCOPED |
| 05 | 3440×1315 | Channel administration | admin topology | No tour-specific residual; topology remains covered by channel lifecycle and control tests. | PASS_SCOPED |
| 06 | 3440×1315 | Text-channel administration | admin channel settings | No tour-specific residual; preserve channel configuration actions. | PASS_SCOPED |
| 07 | 3440×1315 | Audit administration | admin audit | Observation only; no implementation hypothesis or residual identified. | PASS_SCOPED |
| 08 | 3440×1315 | Media administration | admin media | Observation only; the panel is not evidence of media quality or capacity. | PASS_SCOPED |
| 09 | 3440×1315 | Readiness administration | admin readiness | Observation only; readiness display is not a release-gate PASS. | PASS_SCOPED |
| 10 | 3440×1315 | Profile settings | identity settings | #351: settings hierarchy is recorded in its draft branch; profile fields and save state remain covered there. | PASS_SCOPED |
| 11 | 3440×1315 | Security sessions | identity/session settings | #351 covers the settings layout; no session mutation was made in the source tour. | PASS_SCOPED |
| 12 | 3440×1315 | Notification settings | conversation preferences | #351: settings hierarchy and density; preserve current preference state. | PASS_SCOPED |
| 13 | 3440×1315 | About settings | settings/about | No product defect hypothesized; informational panel is retained as a tour baseline. | PASS_SCOPED |
| 14 | 3440×1315 | Audio device settings | voice/audio settings | #351 settings hierarchy; browser fixtures cover layout, but physical audio quality is a separate NOT_RUN gate. | PASS_SCOPED |
| 15 | 3440×1315 | Audio processing settings | voice/audio settings | #342 control consistency and #351 hierarchy; 320px/200% overflow is now fixed and regression-tested. | PASS_SCOPED |
| 16 | 3440×1315 | Search modes | search aside | #340: all modes, labels and keyboard focus fit; current-master matrix checks 320–3440px and 100/200% text. | PASS |
| 17 | 3440×1315 | Search results | search presentation | #340/#346: retain query, filter, result context and scroll; no horizontal overflow. | PASS |
| 18 | 3440×1315 | Mentions | mentions inbox | #346: compact rows, privacy and exact-target navigation remain covered. | PASS_SCOPED |
| 19 | 3440×1315 | Archive | readonly archive | #342/#346: consistent controls, bounded result rows and reader/navigation behavior. | PASS_SCOPED |
| 20 | 3440×1315 | Pinned messages | pins panel | #340/#346: bounded mode tab, compact pin results and navigation. | PASS_SCOPED |
| 21 | 3440×1315 | Quick jump | quick-jump panel | #342/#346: consistent controls and compact, keyboard-reachable people/channel results. | PASS_SCOPED |
| 22 | 3440×1315 | DM list | direct-message navigation | #341: start action and current conversation remain reachable; touch target is 44px. | PASS |
| 23 | 3440×1315 | DM conversation | direct-message conversation | #345/#352: preserve draft, reply, message actions, scroll anchor and header controls. | PASS_SCOPED |
| 24 | 3440×1315 | New DM picker | direct-message starter | #341: top-layer bounded modal, focus/cancel/pagination and one selection; current matrix includes touch. | PASS |
| 25 | 3440×1315 | Emoji picker | message composer | No tour-specific regression recorded; keyboard search and selection remain covered by composer tests. | PASS_SCOPED |
| 26 | 3440×1315 | Attachment viewer | attachment viewer | #345/#346: bounded image viewer and private file navigation; no attachment contents are published. | PASS_SCOPED |
| 27 | 3440×1315 | Create-channel dialog | workspace channel creation | #344: channel navigation and creation actions stay contextual. | PASS_SCOPED |
| 28 | 3440×1315 | Create-channel form | admin channel form | #342: shared native fields/actions; preserve validation and submit state. | PASS_SCOPED |
| 29 | 3440×1315 | Member profile | member popover / roster | #350: collision-aware popover and member-to-DM/voice action scope. | PASS_SCOPED |
| 30 | 3440×1315 | Voice before join | voice prejoin | #347: explicit states, admission/cancel behavior and real two-listener voice session evidence. | PASS_SCOPED |
| 31 | 3440×1315 | Connected voice | voice controls | #347: connect/deafen/leave presentation and two-listener SFU checks; this is not physical audio QoE. | PASS_SCOPED |
| 32 | 3440×1315 | Muted voice | voice controls | #347: mute/deafen state; physical microphone audibility is NOT_RUN. | PASS_SCOPED |
| 33 | 3440×1315 | Screen-share options | screen-share setup | #348: compact setup UI and cancellation; native picker on current master is NOT_RUN. | PASS_SCOPED |
| 34 | 3440×1315 | Screen-share details | screen-share setup | #348: progressive setup/diagnostics; selected profile does not prove output quality. | PASS_SCOPED |
| 35 | 608×609 | Browser capture picker | supported Chrome system picker | Historical production-tour capture only. Current-master supported-Chrome picker smoke: NOT_RUN; in-app-browser error is not treated as a product defect. | NOT_RUN |
| 36 | 3440×1315 | Share source running | screen-share publisher | Historical source capture only; #348 covers real API/SFU publication with synthetic source. Physical source acceptance remains NOT_RUN. | PASS_SCOPED |
| 37 | 3440×1315 | Screen share live | screen-share receiver | Static decoded receiver frame is visual evidence only, not QoE, dynamic video or capacity evidence. | PASS_SCOPED |
| 38 | 3440×1315 | Screen audio help | screen audio guidance | #348 covers guidance states; audible system/game audio is NOT_RUN. | PASS_SCOPED |
| 39 | 3440×1315 | Share diagnostics | screen-share statistics | #348 diagnostic presentation only; no 1080p60 or capacity claim. | PASS_SCOPED |
| 40 | 3440×1440 | Share fullscreen | screen-share viewer | #348 responsive viewer controls; system-level fullscreen behavior is browser-scoped. | PASS_SCOPED |
| 41 | 3440×1315 | TEXT with mini-player | pinned mini-player dock | #349: preserve the same media elements on TEXT/DM navigation; no QoE claim. | PASS_SCOPED |
| 42 | 3440×1315 | Share stopped | screen-share lifecycle | #348 stop/reset state; no retained publisher claim beyond its acceptance evidence. | PASS_SCOPED |
| 43 | 3440×1315 | Voice leave transition | voice disconnect state | Tour frame is transient. #347 later verifies post-leave roster/stream cleanup; no persistent bug reproduced. | PASS_SCOPED |
| 44 | 1351×1054 | In-app browser receiver error | unsupported embedded-browser configuration | RTCPeerConnection.setConfiguration is not a BOOHTACORD defect without reproduction in supported Chrome; current-Chrome check is NOT_RUN. | NOT_RUN |
| 45 | 3440×1315 | Deafened voice | voice controls | #347 deafen state and leave lifecycle; acoustic verification is NOT_RUN. | PASS_SCOPED |
| 46 | 3440×1315 | Login form | authentication | Login state only. Registration and recovery-link flow were not captured in the source tour; NOT_RUN. | NOT_RUN |
| 48 | 3440×1315 | Second Chrome voice client | voice session | Historical source capture; #347 includes current-source real two-listener session evidence. | PASS_SCOPED |
| 49 | 3440×1315 | Two voice participants | voice roster | Historical source capture; #347 verifies actual two listeners and cleanup. | PASS_SCOPED |
| 50 | 3440×1315 | Receiver share available | screen-share receiver | Historical state; #348 covers actual API/SFU subscription, while native picker remains NOT_RUN. | PASS_SCOPED |
| 51 | 3440×1315 | Receiver screen live | screen-share receiver | Decoded static frame is not video QoE; current supported-Chrome picker smoke is NOT_RUN. | PASS_SCOPED |
| 52 | 3440×1315 | Receiver diagnostics | screen-share statistics | Displayed dimensions/FPS are an observation only; no 1080p60 or capacity claim. | PASS_SCOPED |
| 53 | 3440×1315 | TEXT with receiver mini-player | pinned mini-player dock | #349 receiver lifecycle; maintain subscription across TEXT/DM navigation, with quality gates separate. | PASS_SCOPED |
| 56 | 3440×1315 | Conversation menu | conversation actions | #352 header actions are covered by its 11/11 browser fixture; this run does not add a dedicated real-stack assertion for the header menu. | BLOCKED |
| 57 | 3440×1315 | Conversation files | conversation files | #342/#346: shared controls, bounded file rows and contextual message jump. | PASS_SCOPED |
| 58 | 3440×1315 | Mention picker | mention autocomplete | #346: exact-target mention navigation and keyboard/touch rows remain covered. | PASS_SCOPED |

## Current-master browser acceptance

The existing feature fixtures render the production Vue components. On current master, the focused suites passed: search modes 26/26, DM picker 24/24, controls 83/83, chat rhythm/composer 53/53, and search presentation 106/106. The matrices cover CSS widths 320, 390, 768, 1024, 1440, 1920 and 3440 px; root text at 100% and 200% where supported; actual Chromium browser zoom at 200%; pointer, keyboard, and coarse-pointer/touch input. The DM and chat tests keep the selected DM, unsaved draft, ACL behavior, message actions and history anchor; search navigation exercises pins, archive, mentions, files and quick jump.

PR #355 provides source-bound before/after evidence for #340/#341 using production Vue fixtures and same-run geometry/focus assertions. PR #356 records source-sized before/after controls for #342. This run repeats their regressions on the current master; it does not compare only screenshots from different deployed releases.

Three residual layout defects found by the expanded matrix were corrected before the final browser runs:

- The DM start button rendered at 36 px on coarse-pointer widths. It now reaches 44 px and uses the intended header positioning; the 320/390 touch flows select exactly one candidate and preserve the existing draft on cancellation.
- At 320 px and 200% text, the audio refresh action extended to x=-16 and a long native profile select reached x=323.64. The narrow refresh action now joins the content flow, and the audio settings grid can shrink to its viewport. The final controls suite passes all widths and both text scales.
- At 320 px and 200% text, the search form shifted to x=-101 when a date field received focus; its scroll width reached 421 px in a 319 px viewport. Long native scope/author options caused the intrinsic-width overflow. Scope and filter selects now stay within their labels, and mobile date controls use a full row. Geometry assertions now cover the form, fieldset and filter controls; all four 320/390 px at 100/200% cases pass.

## Source-resolution visual review

In the preceding run `.out/local-features/20261017-133410/`, 120 screenshot entries whose pixel hashes changed from run `132437` were inspected at their original dimensions. In the latest run `20261017-134739`, four additional real-stack captures (desktop and mobile search filters and search-result context) were inspected at source resolution. Search query and filter controls fit in the mobile panel with loaded results; the selected context message remains fully visible and focused at both sizes. The desktop context viewport scrolls one preceding row partly out of view while keeping the target complete. The latest report contains 732 selected images, and 101 entries differ by pixel hash from its predecessor; the full current set is not manually reviewed, so status stays `REVIEW_REQUIRED`. The earlier representative review covered desktop message actions and two-listener voice controls, failure and SFU-unavailable states, mobile DM picker/empty DM/voice-after-leave, 320 px/200% diagnostics and filters, and 3440 px/200% files. Generated captures use synthetic QA data and remain under ignored `.out/`; private production-tour frames are not present.

The source-bound component before/after records are in [PR #355 evidence](pr355-search-dm-acceptance-2026-10-16.md) and [DW-03 evidence](dw03-controls-2026-10-16.md). The machine-readable companion lists exact test paths, issue crosswalk and sanitized frame metadata.

## UX tasks and media scope

Find/open channel, DM selection and draft retention, pins, archive, file and mention navigation, voice join/leave, and mini-player continuity have scoped browser and actual-stack evidence in DW-05 through DW-10. The source tour’s voice leave frame is a transient state; #347 later verifies cleanup. The embedded-browser configuration error is not classified as a product bug without supported-Chrome reproduction.

The historical tour did use ordinary Chrome for a static share receiver, but it is not bound to current source. #348 separately covers real API/SFU publication, subscription and decoded synthetic frames. For this current-master gate, supported-Chrome system picker, physical microphone/system audio, dynamic video, QoE/capacity and a 1080p60 claim are **NOT_RUN**. A static receiver image or selected preset is not media-quality evidence.

## Verification and remaining gate

`npm test`: **PASS**, 474 files / 1564 tests. Production typecheck/build: **PASS** (existing LiveKit dynamic-import and chunk-size warnings). Spec traceability: **PASS_INDEX_ONLY**, 39 requirements; the approved Windows brief is unavailable on this host. Contracts did not change. The latest registered Web check `.out/local-features/20261017-134739/` passed unit tests, production build, accessibility, all 19 browser suites, and authenticated real-stack at desktop 1440 px and mobile 393 px. Two earlier consolidated runs (`120656` and `122318`) intermittently missed the `voice.lease_revoked` hint within the 20-second voice-kick wait, with opposite viewport outcomes; isolated retries passed both sizes. The waiter now allows two 15-second notification-worker cycles plus scheduling jitter (40 seconds) and still requires the actual hint. Its raw status is `REVIEW_REQUIRED`: four screenshots from this run were manually inspected, and the full 732-image set remains outstanding; in the preceding run, 120 changed captures were reviewed at source resolution. A sandboxed retry before escalation failed because local browser servers could not bind loopback ports (`EPERM`); the same registered command then passed with loopback access. Current-master native Chrome picker and physical audio remain **NOT_RUN**. Rollout/rollback review for #305 remains **NOT_RUN**.

The acceptance matrix is registered as `issue353` in `tools/qa/local_features/features.json`, and DW-014 is in `backlog/tasks.yaml`. The separate settings/header branches remain unmerged: #351 is draft PR #365 and #352 is a local commit. #354 is deferred because it is an optional P2 preference with no user-valued usability evidence; no compact mode was added.

Full sanitized, machine-readable frame, issue→PR→commit→evidence and status inventory: [JSON companion](dw14-web-tour-regression-2026-10-17.json).
