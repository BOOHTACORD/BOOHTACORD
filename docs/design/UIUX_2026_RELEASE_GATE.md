# UI/UX 2026 release gate

Status: `NOT_RUN` — this is an acceptance protocol, not a release approval. The parent issue #289 stays open until a release owner reviews completed evidence and explicitly accepts or resolves the remaining gaps.

## Evidence trail

[`evidence/qa/uiux-2026-epic-289-2026-10-09.md`](../../evidence/qa/uiux-2026-epic-289-2026-10-09.md) is the current issue → implementation → test → evidence map. Record the commit, build metadata, commands, artifact paths, viewport, platform, and result in that file as each slice lands. `[skip ci]` pushes have local evidence only; they do not create GitHub Actions artifacts.

The current implemented state behavior and deterministic-test mapping are indexed in [`UIUX_2026_STATE_MATRIX.md`](UIUX_2026_STATE_MATRIX.md). Its `Partial` and `NOT_RUN` rows remain open acceptance gaps until the listed response and device scenarios are executed.

The non-skip-ci [Actions run #916](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38068041885) completed successfully for code commit `8b46e4e033b8c78d08590023ba2070ec7ff4f8e5`. It published [responsive-shell](https://github.com/Egkurilov/BOOHTACORD/actions/artifacts/11675652573), [Flutter visual-review](https://github.com/Egkurilov/BOOHTACORD/actions/artifacts/11675692462), [Android debug APK](https://github.com/Egkurilov/BOOHTACORD/actions/artifacts/11675762315), and [Windows x64](https://github.com/Egkurilov/BOOHTACORD/actions/artifacts/11675583644) artifacts, retained through 2026-11-09. This completes CI artifact publication evidence for that tested revision; it does not count as native task acceptance or create artifacts for later `[skip ci]` commits. Detailed IDs, sizes and expiry are recorded in [QA-303](../../evidence/qa/qa303-platform-acceptance-2026-10-10.json).

## User task baseline and comparison

Use the same account fixture, data set, browser/device, viewport, input method, and task wording for baseline and post-change runs. Recruit real testers; do not treat automated checks or developer estimates as user measurements.

| # | Task | Platform / viewport | Baseline result, time, errors/backtracks | Post-change result, time, errors/backtracks | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | Find and open a text channel | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 2 | Send a message and reply to it | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 3 | Find a direct message and search its history | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 4 | Find a guild member | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 5 | Create a text channel in a section | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 6 | Change a member role | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 7 | Join a voice channel | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |
| 8 | Start a screen demonstration | Web desktop / mobile | `NOT_RUN` | `NOT_RUN` | — |

For each attempt, record completion (yes/no), time from task prompt to completion, wrong actions, backtracking, help requested, and any blocking error. Run the same tasks for Flutter on each supported release platform after physical builds are available. Report medians and completion/error counts; keep each platform separate.

**Thresholds:** Approved by release owner Pistol121 on 2026-10-10 (see the recorded criteria below). Tester sample size, baseline/post-change data, and named rollback owners remain `TBD`; no improvement or release decision is claimed until comparable runs are complete.

### Owner-approved thresholds

Pistol121 approved these criteria in the issue work thread on 2026-10-10:

- Compare task success, median time, wrong actions and backtracking separately for desktop and mobile. Require task success to meet or exceed baseline and error/backtracking counts not to increase.
- Treat median time as non-regressing when it is no more than 10% slower on any critical task. Claim a time improvement only when comparable samples show at least a 10% median reduction on a targeted task without violating the other guardrails.
- Roll back or halt the affected cohort if a critical task's success rate drops by at least 10 percentage points, median time is more than 20% slower on two or more critical tasks, or a P1 blocker/data-loss/access-control regression appears.
- Tester count and the named rollback owner for Web, macOS, Windows, Android and iOS still need to be supplied.

Threshold approval does not complete the release gate. Until tester/device runs and rollback ownership are recorded, the release decision remains `NO-GO / NOT_RUN`.

## Platform and artifact matrix

| Surface | Current evidence | Release acceptance |
| --- | --- | --- |
| Web / Chrome desktop and mobile viewports | Local unit/build/accessibility and selected Playwright fixtures are recorded in the evidence file; Chrome 154.0.8037.98 is installed on the macOS host. | `NOT_RUN` — manual task-based tester baseline/post-change and full-app screenshots. Automated fixtures are not physical acceptance. |
| Web / Firefox desktop and mobile | No task-based run recorded for this pass. | `NOT_RUN` — browser/device, screenshot, and task evidence required. |
| Web / Safari desktop and mobile | No task-based run recorded for this pass. | `NOT_RUN` — desktop Safari plus iOS Safari device, screenshot, and task evidence required. |
| Flutter / macOS | Debug app `1.0.38+71` built from `9f8926ba` with a dedicated `.qa` bundle against disposable HTTPS API/LiveKit; code signature verified. After the user confirmed the Mac was unlocked, CUA still listed `.qa` as running but rejected its bundle ID; its shared name resolved to the stopped production bundle. See [QA-303 runtime](../../evidence/qa/qa303-runtime-smoke-2026-10-11.json). | `NOT_RUN` — 800–1920 px resize, native focus/keyboard, capture picker, VoiceOver and task-based usability. No native UI task was counted. |
| Flutter / Android portrait and landscape | Android 15 / API 35 emulator `emulator-5554` ran the current `1.0.38+71` QA build against disposable local HTTPS API/LiveKit. Voice join/reconnect, the app-only capture consent flow, 1440p/60 UI selection, and 2× text/landscape observations are recorded in [QA-303 runtime](../../evidence/qa/qa303-runtime-smoke-2026-10-11.json). The QA package was removed after the run; the production package was untouched. | `PASS_PARTIAL_EMULATOR_ONLY` — physical Android, TalkBack, full IME/task scripts, remote screen-frame receipt, sustained media delivery and reviewer-accessible screenshots remain `NOT_RUN`. |
| Flutter / iOS portrait and landscape | Platform-specific widget coverage exists. No iOS device was discovered on this host. | `NOT_RUN` — physical settings, IME, voice, screen capture, system Back/swipe, and VoiceOver acceptance. |
| Flutter / Windows | Platform-specific widget coverage exists. No Windows device was discovered on this host. | `NOT_RUN` — physical interaction, voice/stream, window controls, and screen-reader acceptance. |

Device discovery on 2026-10-09 at commit `747db023` ran `flutter devices --machine`. It found only the native macOS target (SDK `macOS 26.6.1 25G76 darwin-arm64`) and Chrome (`154.0.8037.98`, `web-javascript`); both reported `emulator: false`. On 2026-10-10, the same command found those targets plus Android 15 / API 35 emulator `emulator-5554` (`emulator: true`). CoreSimulator discovery failed because CoreSimulatorService was unavailable; no iOS simulator or physical iOS device was found. No physical Android device was identified. A pre-existing macOS Debug app process was also observed at version `1.0.38+71`. Its executable timestamp (`2026-10-08 21:34 MSK`) predates the current source edit (`2026-10-09 22:06 MSK`), so this binary cannot verify the current source. A 1440×900 audio-settings screen and its accessibility tree were inspected transiently, but no screenshot was archived and no task was counted as passed. The session was already authenticated against a populated guild; `docker ps` found no separate local QA stack. The Flutter app defaults to the production API origin and has no QA-origin override in its startup configuration, so the Android emulator was not launched against the populated production account. No message, channel, role, voice, or screen-share mutation was attempted in that session. No manual task script, assistive-technology session, or full-app screenshot comparison was performed. The 2026-10-11 isolated Android QA follow-up adds emulator-only partial results in [QA-303 runtime](../../evidence/qa/qa303-runtime-smoke-2026-10-11.json). Physical acceptance, complete task scripts, TalkBack, remote frame receipt and reviewer-accessible screenshots remain `NOT_RUN`.

The original 41 reference screenshots are recorded in the visual audit at local path `artifacts/ui-ux-screenshots.zip`, but ZIP files under `artifacts/` are ignored and the archive is not tracked in this repository. Clean CI checkouts cannot inspect the source images. Current shell/DOM/widget tests are regression evidence, not full-app before/after comparison against those assets. No screenshot or device gate is passed by this document.

## Rollout and rollback

- Roll out UI-only changes through the existing Web and Flutter release processes in separate platform cohorts. Keep each cohort's build identifier and evidence link with the release record.
- Protocol, database, ACL, session-cookie, and media transport contracts are outside this UI package; any proposed contract change requires its own review and release plan.
- Web rollback: redeploy the last known-good immutable Web artifact or revert the UI-only commit and produce a new artifact.
- Flutter rollback: halt the affected platform cohort and use the existing platform release rollback/update process to return to its last known-good build. Record store/desktop packaging constraints before rollout.
- Release owner and per-platform rollback owner: `TBD — assign before rollout`.
- Release decision: `NO-GO / NOT_RUN` until tester evidence, platform acceptance, artifact references, owner assignments, and screenshot gaps are reviewed. An owner may record accepted exceptions with rationale and follow-up issue; do not relabel `NOT_RUN` as `PASS`.

## Runtime follow-up — 2026-10-11

- [QA-303 runtime smoke](../../evidence/qa/qa303-runtime-smoke-2026-10-11.json) records a partial Android 15/API 35 emulator pass against the disposable local QA stack. Channel and DM send/search/edit/react, admin surfaces (view-only), settings persistence, destructive cancellation and root Back were observed. It is emulator evidence only; physical Android, voice join, screen sharing, reconnect, landscape, dynamic text, keyboard traversal and TalkBack remain `NOT_RUN`.
- A macOS debug QA build was built and launched against the local QA endpoint. The CUA bridge rejected the isolated `.qa` bundle identifier, so no Mac UI task was counted as passed. Window resize, focus/input, capture picker and VoiceOver remain `NOT_RUN`.
- Android screenshots and hashes are retained in the ignored local `.out` directory and are not staged or published. They are not reviewer-accessible artifacts; screenshot publication remains an open gate.
- #303 and #289 remain open. This checkpoint does not change the release decision: `NO-GO / NOT_RUN`.

## Android emulator voice/share follow-up — 2026-10-11

- The current Flutter QA build joined the disposable local voice room, recovered after a short local proxy outage, opened Android’s single-app capture consent and selected the uniquely labelled `BOOHTACORD QA` package. The local roster showed the screen-share indicator while Android reported an active MediaProjection for `ru.boohtacord.app.qa`; no second client verified video frames or sustained delivery.
- The screen-share quality controls exposed 720p, 1080p, 1440p and 15/30/60 FPS. Selecting 1440p/60 updated the current selection and accessibility selected state. This is UI-state evidence, not encoder or network QoE evidence.
- At 2× text the screen-share content scrolled with the footer fixed and voice controls remained visible. The channel subtitle visually ellipsized, while its full accessibility label remained available. TalkBack was not run.
- The Android system capture consent prompt did not show a visible Start action at 2× text in landscape; the QA flow was completed at portrait/1×. This observation is limited to the emulator’s system dialog.
- The emulator was restored to 1×/portrait; the microphone permission was revoked, `.qa` was uninstalled, ADB reverse mappings were removed and the disposable stack was stopped. The production package was not opened or changed.
- Physical Android acceptance remains `NOT_RUN` because the emulator is the only available device. #303 and #289 remain open; the release decision remains `NO-GO / NOT_RUN`.

## Desktop resize follow-up — 2026-10-11

- The desktop minimum window width is now 800 logical pixels (previously 1024), matching the lower edge of UX-02's 800–1920 px resize scenario. The existing 1440×900 launch size and 680 px minimum height are preserved.
- `flutter test test/desktop_window_options_test.dart` and `flutter build macos --debug` pass. The focused result is recorded in [QA-291](../../evidence/qa/qa291-desktop-window-width-2026-10-11.json).
- Native drag-resize and OS panel interaction remain `NOT_RUN`: the macOS QA process was listed as running, but CUA could not bind its window; no Windows runner was available. #291, #303 and #289 remain open.


## Native macOS QA retry — 2026-10-11

- The user unlocked the Mac and an isolated Flutter debug build v1.0.38+71 was launched with bundle ID `ru.boohtacord.boohtacordDesktop.qa` against the disposable local HTTPS API/LiveKit stack. Build and code-signature verification passed; executable SHA-256: `50cd2f7eaf16021feb59ee44c28a84e75477ff4f708998623e070d208ee501d6`.
- CUA exposed the app as running but rejected binding by bundle ID, exact path and unique display name. The production app remained not running; no UI input or screenshot was captured.
- The UI gate is still `NOT_RUN`. Resize, focus/keyboard, system capture picker and VoiceOver need a CUA-bindable isolated app or an approved native UI bridge. QA-only source edits and temporary credentials/pin were removed; the disposable backend exited cleanly.