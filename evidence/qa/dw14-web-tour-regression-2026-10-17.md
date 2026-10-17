# DW-14 — web-tour regression bridge

State: **REVIEW_REQUIRED**. The latest registered Web run `.out/local-features/20261017-170617` passed all 27 automated stages: 474 unit-test files / 1,571 tests, production build, accessibility, 23 browser suites, and authenticated API/PostgreSQL/LiveKit journeys at 1440px and 393px. Current `master` is `43d0c491575f83f03d72bb7355392ce82f56d998`; PR #367 for #352 has merged there. The validated issue-353 tree is commit `f7881097`. The runner recorded the pre-commit checkout plus its working-tree diff as `ed4cb5e5871c64720b1dd9f43ca5f7406f5ee0ff diff-sha256=5550c0b2726e450d88bfae5d77c3480d734593a5e1b6047153ee8011a75c4696`; that diff is represented by `f7881097`. Eight current-run images were inspected at source resolution; 990 of 998 unique images remain unreviewed, so the visual gate remains `REVIEW_REQUIRED`. The 15 October production tour showed Web 1.0.32 / r-stable-r46; its deployed SHA is unverified, so it remains a historical observation.

The local tour contains 55 available frames. The source images include account and conversation data and remain private; this report publishes no original images, user names or DM text. Missing IDs are 47, 54 and 55. Each frame below is mapped by sanitized state, viewport, UI owner and treatment.

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
| 43 | 3440×1315 | Voice leave transition | voice disconnect state | #347 verifies cleanup; #353 also keeps voluntary leave neutral while failures remain errors. | PASS_SCOPED |
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

The fixtures render production Vue components. Registered run `.out/local-features/20261017-170617` passed unit tests (474 files / 1,571 tests), the production build, accessibility, all 23 registered browser suites, and both authenticated real-stack stages. The real-stack journeys passed at desktop 1440px and mobile 393px against the local API, PostgreSQL and LiveKit services. The issue-353 regressions keep the viewer diagnosis stable while receiver samples change, keep the mobile screen-share notice clear of the DM send button, and style voluntary voice leave as a neutral status. A debounce of 1.2 seconds filters transient receiver `hasAudio` changes; selection changes apply immediately.

The browser matrix also covers CSS widths 320, 390, 768, 1024, 1440, 1920 and 3440px, root text at 100% and 200%, actual Chromium zoom at 200%, pointer, keyboard and touch. The DM and chat tests retain the selected DM, unsaved draft, ACL behavior, message actions and history anchor; search navigation covers pins, archive, mentions, files and quick jump. PR #367, which carries #352 header actions, merged to current `master` at `43d0c491575f83f03d72bb7355392ce82f56d998`; issue #353 is tested directly on that base.

## Source-resolution visual review

The latest registered run `.out/local-features/20261017-170617` produced 1,051 selected PNG captures and 998 unique images. Eight distinct current-run images were inspected at original pixel resolution: desktop and mobile viewer diagnosis, the mobile notice above the DM composer, desktop and mobile voice-after-leave, desktop and mobile real-stack mini-player in a DM, and mobile share statistics. Their paths, dimensions and SHA-256 hashes are recorded in the JSON companion. The paired 393×852 CSS-pixel real-stack captures show the fix directly: before, the notice overlays the composer border and send button; after, it sits between the mini-player and conversation header. Before SHA-256: `a23dafba0c5f292c1df8b570c128b4e4fff2989a546788977b362d29e739d3b7`; after SHA-256: `730d143508aa4dd79e7d3ad2448fba3a1faf335087b1ce028e52a2fe04c32e83`. Both 1179×2556-pixel images were inspected at original resolution, and their local paths are in the JSON companion. The composer send button is clear after the change. Voluntary leave is neutral at both real-stack viewports. The statistics distinguish the selected sender profile from measured receiver dimensions and mark unavailable readings as stale/absent; they make no quality claim.

Eight of 998 unique current-run images have direct visual review; 990 remain unreviewed, so the result is `REVIEW_REQUIRED`. Earlier screenshot review records remain in the JSON as historical evidence and are not counted for this source without a current exact-hash match. Synthetic captures do not establish current Chrome picker, physical audio, dynamic video, QoE or capacity acceptance. Original production-tour screenshots remain private and are not copied into the repository.

## UX tasks and media scope

Find/open channel, DM selection and draft retention, pins, archive, file and mention navigation, voice join/leave, and mini-player continuity have scoped browser and actual-stack evidence in DW-05 through DW-10. The source tour’s voice leave frame is a transient state; #347 later verifies cleanup. The embedded-browser configuration error is not classified as a product bug without supported-Chrome reproduction.

The historical tour did use ordinary Chrome for a static share receiver, but it is not bound to current source. #348 separately covers real API/SFU publication, subscription and decoded synthetic frames. For this current-master gate, supported-Chrome system picker, physical microphone/system audio, dynamic video, QoE/capacity and a 1080p60 claim are **NOT_RUN**. A static receiver image or selected preset is not media-quality evidence.

## Verification and remaining gate

The final registered command was `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --base github/master --real-stack` in `.out/local-features/20261017-170617`. All 27 stages passed: 474 files / 1,571 unit tests, production typecheck/build, accessibility, 23/23 browser suites, and authenticated real-stack journeys at 1440px and 393px. The production build reported the existing LiveKit ineffective dynamic-import and large-chunk warnings. Spec traceability remains `PASS_INDEX_ONLY` for 39 requirements because the approved Windows brief is unavailable on this host; contracts were unchanged. The raw local report SHA-256 is `bae911c95ae31148ca85d49c704393bbe9f987f970a63b4d2b698da45a6d514b` (`336744` bytes); its runner source record is `ed4cb5e5871c64720b1dd9f43ca5f7406f5ee0ff diff-sha256=5550c0b2726e450d88bfae5d77c3480d734593a5e1b6047153ee8011a75c4696`, corresponding to validated commit `f7881097`.

Visual review is partial: 8 of 998 unique current-run images were inspected at source resolution and 990 remain unreviewed, so the issue remains `REVIEW_REQUIRED`. Supported-Chrome native picker, physical microphone/system audio, dynamic video, media QoE/capacity, and 1080p60 acceptance remain `NOT_RUN`. Rollout/rollback review for #305 remains `NOT_RUN`. These gates are recorded separately from the passed synthetic real-stack journeys.

Full sanitized, machine-readable frame, issue→PR→commit→evidence and status inventory: [JSON companion](dw14-web-tour-regression-2026-10-17.json).
