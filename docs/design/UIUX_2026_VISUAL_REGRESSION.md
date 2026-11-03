# UI/UX 2026 visual regression inventory

This inventory supports epic [#289](https://github.com/BOOHTACORD/BOOHTACORD/issues/289) and verification task [#302](https://github.com/BOOHTACORD/BOOHTACORD/issues/302). The machine-readable 41-slot screen catalog is [`clients/web/tests/uiux_2026/visual_matrix.json`](../../clients/web/tests/uiux_2026/visual_matrix.json); its Vitest contract ensures the desktop/mobile counts, fixture/test paths, viewport targets, expected behavior and owner field stay populated.

## Reference archive status

The original archive used for the local audit is named `artifacts/ui-ux-screenshots.zip`, but ZIPs under `artifacts/` are ignored and the archive is not tracked here. Clean checkouts do not include the source PNGs; provide the archive at that local path to rerun archive-backed checks. The local audit inventory lists all 41 PNGs (18 desktop, 23 mobile); `D18` and `M23` are `desktop-channel-log.png` and `mobile-channel-log.png`. The catalog records the archive SHA-256, each filename, the CSS viewport, and the PNG raster size. Desktop references are 1440×900 CSS px / 2880×1800 raster px. Mobile references are 393×852 CSS px / 1179×2556 raster px, except the two stream-launch references at 786×1704.

The source archive does not include the current branch's “after” screenshots. The 1440×900 and 393×852 targets below match the source capture dimensions; the separate #302 regression sweep also includes 390×844 from #290.

## Source archive integrity

The 41 named PNG entries contain 40 unique image payloads. `desktop-guild-settings.png` is byte-identical to `desktop-guild-members.png` (SHA-256 `0a0ba90ad3288815fa4925b540396e74defaf463f4542fe38c6370c5ff57ff57`). The D11 catalog slot is mapped to the actual Web and Flutter guild-settings flows and marked `BLOCKED_DUPLICATE_BASELINE`; it must not be counted as an independent desktop before/after comparison until the source desktop settings screenshot is corrected. The matrix verifier now derives duplicate-content findings from the pinned archive and checks that the affected slot remains explicitly blocked.

The responsive-shell sweep emits fixture captures for geometry and history checks. Separately, the autonomous lifecycle runner captures the actual production Web app against an isolated Go API, PostgreSQL and Tempo stack at 393×852 (mobile emulation, DPR 3, touch), 1024×768, and 1440×900 (DPR 2). The mobile and desktop runs retain initial and saved guild-settings screenshots at the source raster sizes under ignored `.out/client-lifecycle/{393,1440}/`; bounded reports for all three viewports record the source-file and screenshot hashes, API restart persistence, trace privacy, and owned-resource cleanup. The M14 mobile settings capture was visually inspected against the actual full-app run. These are runtime review captures, not approved goldens or coverage of all 41 source screens. The D11 desktop reference remains blocked because its archive payload duplicates the members screenshot. The six admin views other than settings have been visually reviewed at the source mobile and desktop sizes against the matching references, with the same seeded density fixture; the catalog records those slots as reviewed captures, not approved pixel goldens.

### Readiness layout follow-up

The lifecycle runner now also captures all seven guild-admin sections. Review of the production `guild-readiness.png` images found the service probes and storage `<dt>/<dd>` values had no dashboard layout and appeared as a narrow column at desktop widths. `clients/web/src/design/design_v2_admin_readiness.css` now renders dependency and capacity values as token-based cards: three columns on desktop, two on medium widths, and one below 420 px. It also styles status badges and the synthetic journey panel. The production-component Playwright regression checks that both grids occupy the available section width at 320, 390, 600, 840 and 1440 px, that each label/value remains inside its card, and that the document does not overflow horizontally.

After the fix, full-stack production runs passed again on commit `55f18d2b179ab87f93a9cb1d08ed9b3fffff338c` at 393×852 and 1440×900. Their local `guild-readiness.png` SHA-256 values are `97c9094bd26081bb0b8e82f87051433099b56598bf1bb031676b11d619ed3549` (mobile) and `d7c8a275952522a111704028063f5db5e3ccd09eadaa37e3811ae1be1ad39fc8` (desktop). The report JSON SHA-256 values are `607432e847d86d4cbbc19026c6ea6707f5879808c0ab3bf51067bf0e0498ca12` (mobile) and `062afb4fc5554ca84ffc892039debe61479f1e867a52bcb9c0151d0711327d1f` (desktop); suite results are recorded in [`evidence/qa/uiux-2026-epic-289-2026-10-09.md`](../../evidence/qa/uiux-2026-epic-289-2026-10-09.md). The disposable backend reports SFU unavailable and insufficient protected storage, so these captures verify presentation of degraded health and responsive geometry; they do not prove production health or serve as approved screenshot goldens. They remain local under ignored `.out/client-lifecycle/` because the user requested `[skip ci]` pushes.

## Automated viewport coverage

`npm run test:responsive-shell` runs the production responsive-shell CSS and workspace drawer-history/focus helpers at 12 sizes. It checks shell/composer/voice-dock bounds, document overflow, selected-channel retention, drawer behavior, browser Back/Forward, voice context, focus containment and focus restoration. A production-style channel row also verifies the favorite and channel-action controls stay inside the row at 320/390/600/840/1024/1440 px; the two mobile actions are at least 44×44 px. The six required #302 sizes and both exact source-reference CSS sizes are captured on each run:

| Viewport | Capture |
| --- | --- |
| 320×640 | `shell-320x640.png` |
| 390×844 | `shell-390x844.png` |
| 768×1024 | `shell-768x1024.png` |
| 1024×768 | `shell-1024x768.png` |
| 1440×900 | `shell-1440x900.png` |
| 1920×1080 | `shell-1920x1080.png` |
| 393×852 | `shell-393x852.png` |

The images are emitted under `.out/responsive-shell-browser-results/` and retained as the `ux-responsive-shell-<commit>` artifact by `ci-frontend.yaml`. They are review captures; the current test checks geometry and state invariants, not pixel equality to a golden. CI wiring is in `tools/ci/native/web.py`.

`python3 -m tools.verify.uiux_visual_matrix` validates the pinned archive SHA-256, all 41 archive entries and PNG dimensions when the ignored source ZIP is supplied. In a clean checkout without that ZIP, it reports `NOT_RUN` for archive-byte validation while still checking catalog counts and referenced test mappings. The catalog contract test validates the 41-slot inventory. The current shell sweep complements focused production-component browser fixtures for message actions, DM/search, admin states, settings, dialogs and voice/stream setup. Flutter has focused widget/layout coverage listed per catalog entry. These suites do not collectively prove that every one of the 41 source screens has a matching, source-backed golden.

The full-stack lifecycle runner exercises a production Web build at mobile 393×852, tablet 1024×768, and desktop 1440×900 using two independent Chrome sessions, real session cookies and ACLs, a disposable Linux API container, PostgreSQL and Tempo. It checks data persistence after an API restart and verifies that its labeled resources are removed. Use its initial/saved screenshots to review the actual application flow; use the report hashes to bind them to their source files. The run is recorded in the issue evidence file. It does not replace per-screen visual comparison, physical device acceptance or GitHub artifact retention.

### Recapture after a UI-approved change

1. If the original audit archive is supplied locally at `artifacts/ui-ux-screenshots.zip`, keep it immutable. A new approved capture is evidence for a reviewed change; it does not silently replace the source archive.
2. Run the Web viewport/capture suite from `clients/web`: `npm run test:responsive-shell`. It writes the six required targets plus the 393×852 source-reference target under `.out/responsive-shell-browser-results/`.
3. Run the actual-app admin captures from the repository root with installed Chrome and the disposable lifecycle stack: `QA_BROWSER_EXECUTABLE=<Chrome executable> python3 -m tools.qa.client_lifecycle.run --width 393` and repeat with `--width 1440`. This writes source-sized screenshots and a bounded, hash-bound report under `.out/client-lifecycle/{393,1440}/`.
4. Compare the named, stable layout regions against the matching source screen and inspect the matching DOM/state assertions. Treat timestamps, avatars, member identities, audit payloads and live service values as dynamic data: document their region or fixture rule in the catalog and review the region manually; do not make their raw pixels a flaky pass/fail gate. Report only observed differences, and distinguish them from hypotheses.
5. For a GitHub Actions artifact, run the `CI` workflow on the reviewed branch and verify `ux-responsive-shell-<commit>` is attached to that exact run. A `[skip ci]` push has no such artifact. Record the commit, report hashes, artifact URL and reviewer-approved status in the evidence record before changing a catalog row to an approved golden.

The current #296 review records source-sized captures for the six admin views other than Guild Settings. Their runtime capture status deliberately remains `REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN` until the owner approves a retained after image; the duplicated D11 source also needs correction before it can supply an independent baseline.

This lifecycle run does not include the critical real-SFU outage/restart flow. That separate flow remains `NOT_RUN`: macOS Chrome could not establish ICE through the local Colima host-network boundary, while a Linux browser reached voice join and chat-WebSocket-only recovery but could not control the owned SFU for the later stop/restart stage. Do not count either partial run as voice fault-recovery acceptance.

## Remaining work for #302

- Bind each catalog slot to a dedicated, runnable Web and Flutter fixture; the existing fixtures cover representative behaviors, not all 41 full screens.
- Convert the reviewed #296 admin captures into approved, deterministic comparisons and extend those source-backed captures to the other critical flows, with documented dynamic-region masks and exceptions.
- Extend Flutter visual coverage beyond the screen-share setup widget matrix, which now checks compact 320×640, medium 768×1024 and expanded 1440×900 at 1×/2× text, dark theme, safe-area and IME fixtures. Add approved goldens for the remaining catalog screens and retain review artifacts.
- Run the connected GitHub Actions workflow and verify the browser captures are attached. The latest user-requested `[skip ci]` push does not provide a workflow artifact.

The six admin views recorded as `REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN` have source-sized runtime captures and visual review evidence. They are not approved pixel goldens. Source-backed comparisons for other critical flows, complete per-slot fixtures, Flutter goldens and retained CI artifacts remain outstanding.
