# UI/UX 2026 accessibility inventory

Scope: GitHub [#301](https://github.com/Egkurilov/BOOHTACORD/issues/301), key interaction scenarios shared by Web and Flutter. The machine-readable control/test map is [`clients/web/tests/accessibility/uiux_2026_inventory.json`](../../clients/web/tests/accessibility/uiux_2026_inventory.json). A catalog status of `PASS_SCOPED` means the listed automated cases pass; it does not mean that every control in the scenario or every platform is conformant. `PARTIAL` and `NOT_RUN` remain explicit.

## Controls, actions and automated coverage

| Scenario | Web controls/actions | Flutter controls/actions | Current automated status |
| --- | --- | --- | --- |
| Guild navigation | Skip link, guild/navigation toggles, channel buttons, favorite/action controls, mobile drawer close and focus return | Navigation drawer, channel selection, system Back, channel/action semantics | Scoped Web and widget coverage passes; physical and screen-reader traversal not run. |
| Chat and DM | Composer, attachments/mentions, message actions, DM search and source-context return | Composer/attachment actions, message actions and semantics | Scoped browser/Widget coverage passes; physical keyboard and screen-reader task not run. |
| Admin | Seven tabs; member search/role/status/reset; role/topology review; audit/readiness/media status | Seven sections; member/audit/role controls; live-region and focus behavior | Flutter regression checks all seven compact tab labels, tab roles and selected states; focused Web/Flutter admin and responsive-state suites pass. Full rendered-state and screen-reader coverage remains partial. |
| Settings | Linked profile tabs; form labels/save feedback; session confirmations; unsaved-change guard | Profile settings and shared semantic theme | Focused form, tab and widget checks pass; native audio/device settings remain outside this slice. |
| Dialogs | Named modal, Cancel-first focus, keyboard containment, Escape, focus return, stale-target dismissal | Dialog semantics, Cancel-first Enter, Escape/Back, modal barrier and IME layout | Focused browser and widget cases pass; assistive-technology announcement review not run. |
| Voice | Prejoin/device actions, join, connected/reconnecting/ended status, shortcuts and timeout feedback | Prejoin status, connected dock actions, connection badge states, retry and shortcut feedback | Scoped Web/Flutter widget coverage passes; Flutter's broader screen-reader review remains partial. No physical keyboard or live-media screen-reader task was performed. |
| Stream setup | Scenario, resolution/FPS radio names, 1440p supported-profile transition, named close/cancel/start actions, failure feedback and reduced motion | Setup actions, capability/profile labels, responsive dialog geometry | Scoped browser/widget checks pass; native picker and assistive-technology acceptance not run. |

The individual paths, control lists and per-client status live in the JSON inventory. This document separates automated evidence from manual acceptance so a passing axe/widget run is never presented as a physical screen-reader result.

Flutter's voice badge regression checks every connection status. Disconnected and error announce distinct live-region labels and hide connection quality/ping values, even if stale measurements are supplied. This is semantics-tree evidence; physical TalkBack/VoiceOver traversal remains `NOT_RUN`.

## Contrast and target size

The sampled opaque token pairs and WCAG relative-luminance ratios are recorded in [`DESIGN_V2_TOKEN_CROSSWALK.md`](DESIGN_V2_TOKEN_CROSSWALK.md#opaque-color-pair-contrast-snapshot), with focused Web and Flutter regression tests. Measured normal-text examples include primary text on content/sidebar/surface at `15.98 / 17.04 / 15.46:1`, secondary text at `9.24 / 9.86 / 8.94:1`, and white on accent at `4.61:1`. Focus on content/surface measures `8.03 / 7.77:1`; control outline on surface measures `3.95:1`. Disabled text is `4.06:1` on content and `3.93:1` on surface and is not an active or essential text color.

These measurements cover sampled token pairs, not every rendered combination, image, translucent overlay or component state. The product target for actionable controls is at least 44×44 CSS px on Web and 44×44 logical px on Flutter, exceeding the WCAG 2.2 AA 24 px minimum where applicable. Browser and widget tests cover selected high-risk controls, including message actions and compact admin controls.

The Web message-action axe scan initially found `2.66:1` for a system-message mention and `2.26:1` for its delete control. The semantic accent/danger token fix removed those violations in the tested fixture. This is verified component evidence, not a whole-app contrast certification.

A Flutter semantics review found the seven `AdminTabControl` nodes had a tab role and selected state but blank accessible names: their visible labels were inside `ExcludeSemantics`. The control now explicitly exposes its localized visible label. `test/admin_media_widget_test.dart` checks all seven labels plus the `tab` role; the focused file passes 6 tests, and `test/admin_accessibility/keyboard_test.dart` confirms keyboard activation and visible focus. The test was run red first (`Медиа` expected, empty label returned) before the fix. This closes the automated name check for the admin tab strip only; it does not replace TalkBack/VoiceOver traversal.

## Manual acceptance

| Platform path | Result | Limitation |
| --- | --- | --- |
| Web keyboard and screen-reader smoke | `NOT_RUN` | Automated browser keyboard and axe checks pass in the listed fixtures; no VoiceOver/NVDA session was performed on the current candidate. |
| Flutter TalkBack | `NOT_RUN` | Semantics/widget tests pass in focused areas; no Android physical-device traversal was performed. |
| Flutter VoiceOver | `NOT_RUN` | No iOS device or simulator was available for a current-code traversal. |
| macOS VoiceOver | `NOT_RUN` | A current task-based native screen-reader smoke was not run. |
| Windows Narrator and keyboard traversal | `NOT_RUN` | No Windows device or VM was available. |

`NOT_RUN` is a release gate where the platform issue requires it. These results do not claim zero known WCAG 2.2 AA findings across all seven flows; they record the currently passing automated subset and its explicit limits.
