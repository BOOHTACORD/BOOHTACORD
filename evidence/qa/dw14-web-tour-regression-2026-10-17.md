# DW-14 — web-tour regression bridge

State: **BLOCKED_WITH_REVIEW_REQUIRED**. The latest registered run passed all 22 browser suites, but its two authenticated real-stack stages could not start on this host because Python was denied binding `127.0.0.1:4880` (`EPERM`). Earlier real-stack evidence is retained separately. Base master is `8f4b15a6ffb0d29389ecf45189be147b2f708227`; the latest source snapshot is `218486389a36cab377b9be3457d1bc17bedde638`, stacked on open PR #367 at `d79f6b2cc1d9e584842a05922934f5926b739d92`. The 15 October tour showed Web 1.0.32 / r-stable-r46; its deployed SHA is unverified, so it remains a historical observation.

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
| 10 | 3440×1315 | Profile settings | identity settings | #351 settings hierarchy is merged via PR #366; profile fields and save state remain covered by the existing settings tests. | PASS_SCOPED |
| 11 | 3440×1315 | Security sessions | identity/session settings | #351 settings layout is merged via PR #366; no session mutation was made in the source tour. | PASS_SCOPED |
| 12 | 3440×1315 | Notification settings | conversation preferences | #351 settings hierarchy and density are merged via PR #366; preserve current preference state. | PASS_SCOPED |
| 13 | 3440×1315 | About settings | settings/about | No product defect hypothesized; informational panel is retained as a tour baseline. | PASS_SCOPED |
| 14 | 3440×1315 | Audio device settings | voice/audio settings | #351 settings hierarchy is merged via PR #366; browser fixtures cover layout, but physical audio quality is a separate NOT_RUN gate. | PASS_SCOPED |
| 15 | 3440×1315 | Audio processing settings | voice/audio settings | #342 control consistency and merged #351 hierarchy; the 320/390px, 200% text diagnostic overlap is fixed and regression-tested. | PASS_SCOPED |
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
| 56 | 3440×1315 | Conversation menu | conversation actions | PR #367 covers the #352 header actions with its 11/11 browser fixture; no dedicated real-stack assertion is included for the header menu. | PASS_SCOPED |
| 57 | 3440×1315 | Conversation files | conversation files | #342/#346: shared controls, bounded file rows and contextual message jump. | PASS_SCOPED |
| 58 | 3440×1315 | Mention picker | mention autocomplete | #346: exact-target mention navigation and keyboard/touch rows remain covered. | PASS_SCOPED |

## Current-master browser acceptance

The fixtures render production Vue components. Registered run `20261017-153155` passed unit (474 files / 1571 tests), production build and all 22 browser suites; only its two real-stack startup stages were blocked by loopback permission before assertions ran. The earlier pre-rebase run `20261017-151403` completed desktop 1440px and mobile 393px real-stack journeys. The current branch adds a regression that keeps “Источник не публикует аудиодорожку.” stable while receiver samples are absent, fresh or stale; the model and focused browser tests pass. Other browser matrices cover CSS widths 320, 390, 768, 1024, 1440, 1920 and 3440px, root text at 100% and 200%, actual Chromium zoom at 200%, pointer, keyboard and touch. The DM and chat tests retain the selected DM, unsaved draft, ACL behavior, message actions and history anchor; search navigation covers pins, archive, mentions, files and quick jump.

PR #355 provides source-bound before/after evidence for #340/#341; PR #356 records source-sized before/after controls for #342. The current integration branch repeats those regression fixtures atop PR #367, which carries #352 header actions.

The expanded matrix identified and corrected these layout defects before the latest browser runs:

- The DM start button rendered at 36 px on coarse-pointer widths. It now reaches 44 px and uses the intended header positioning; the 320/390 touch flows select exactly one candidate and preserve the existing draft on cancellation.
- At 320 px and 200% text, the audio refresh action extended to x=-16 and a long native profile select reached x=323.64. The narrow refresh action now joins the content flow, and the audio settings grid can shrink to its viewport. The final controls suite passes all widths and both text scales.
- At 320 px and 200% text, the search form shifted to x=-101 when a date field received focus; its scroll width reached 421 px in a 319 px viewport. Long native scope/author options caused the intrinsic-width overflow. Scope and filter selects now stay within their labels, and mobile date controls use a full row. Geometry assertions now cover the form, fieldset and filter controls; all four 320/390 px at 100/200% cases pass.
- At 320/390 px and 200% text, long audio-processing labels shared a two-column row with their values. The diagnostic values now use a single column at narrow widths, and geometry assertions confirm each value follows its label without overlap. Long selected labels inside native audio selects still truncate at this scale; their full choices remain available when the select opens, and this visual note is recorded separately.

## Source-resolution visual review

The latest browser run `.out/local-features/20261017-153155/` produced 972 selected PNG captures and 923 unique images. 79 images exactly match reviewed hashes from the previous 286-image review set. Four additional current-run images were inspected at source resolution: the desktop fresh-sample and 390px/200% stale-sample diagnosis views, the 1024px/200% share-quality dialog, and the 1024px/200% technical receiver panel. The diagnosis stays stable as the receiver sample timestamp changes; the mobile status wraps across lines but remains readable. The quality dialog fits its viewport. Long technical receiver labels and values wrap densely and continue below the captured viewport; this static screenshot does not establish panel scrolling.

Together, 83 of 923 unique current images have review evidence; 840 remain unreviewed, so visual status stays `REVIEW_REQUIRED`. The earlier 57 direct reviews and 229 exact matches described the prior source snapshot; only byte-identical images were carried to this run. Synthetic previews do not establish current Chrome picker, physical audio, dynamic video, QoE or capacity acceptance. Production tour screenshots remain private and are not copied into the repository.

## UX tasks and media scope

Find/open channel, DM selection and draft retention, pins, archive, file and mention navigation, voice join/leave, and mini-player continuity have scoped browser and actual-stack evidence in DW-05 through DW-10. The source tour’s voice leave frame is a transient state; #347 later verifies cleanup. The embedded-browser configuration error is not classified as a product bug without supported-Chrome reproduction.

The historical tour did use ordinary Chrome for a static share receiver, but it is not bound to current source. #348 separately covers real API/SFU publication, subscription and decoded synthetic frames. For this current-master gate, supported-Chrome system picker, physical microphone/system audio, dynamic video, QoE/capacity and a 1080p60 claim are **NOT_RUN**. A static receiver image or selected preset is not media-quality evidence.

## Verification and remaining gate

`npm test`: **PASS**, 474 files / 1571 tests. Production typecheck/build: **PASS** with existing LiveKit dynamic-import and chunk-size warnings. Spec traceability: **PASS_INDEX_ONLY**, 39 requirements; the approved Windows brief is unavailable on this host. Contracts did not change. The latest registered check is `.out/local-features/20261017-153155/`, run against `refs/remotes/localroot/issue352-head` with chat, shell, voice and screen features. It passed 24 of 26 stages: unit, production build and all 22 browser suites. The two real-stack stages stopped before service startup when `ports_available` received `PermissionError: 127.0.0.1:4880 (EPERM)`, so the final rebased-source real-stack gate is **BLOCKED**, not a product failure or PASS. The latest report has 972 selected captures / 923 unique; 4 current images were reviewed directly and 79 exact prior-image matches carry forward, leaving 840 unique images unreviewed. The voice-interface suite passes; native Chrome picker, physical microphone/system audio, dynamic video, QoE/capacity and a 1080p60 claim remain **NOT_RUN**. Rollout/rollback review for #305 remains **NOT_RUN**.

The acceptance matrix is registered as `issue353` in `tools/qa/local_features/features.json`, and DW-014 is in `backlog/tasks.yaml`. Issue #351 is merged via PR #366; the superseded draft PR #365 remains open and was not altered. Issue #352 is open as PR #367. Issue #353 is being published as a draft stacked on PR #367. #354 remains deferred because it is an optional P2 preference without user-valued usability evidence; no compact mode was added.

Full sanitized, machine-readable frame, issue→PR→commit→evidence and status inventory: [JSON companion](dw14-web-tour-regression-2026-10-17.json).
