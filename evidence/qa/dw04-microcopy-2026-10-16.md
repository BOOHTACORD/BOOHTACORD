# DW-04 / #343 — contextual Web microcopy

State: PASS_SCOPED (#343 Web microcopy). Base master `c6e789bb39b25d46a223d85c338959480cebb32e`.
Leaf DW-004; dependencies T-050/T-041/T-022/T-014/DW-003.

The original private web-tour archive is unavailable here. No unobserved tour
text is claimed as an existing defect. New captures use production Vue components
with explicit synthetic API data, not production accounts. The catalogue
`dw04-copy-catalog-2026-10-16.json` records actual selectors, strings, visibility,
decisions, source screenshot hashes and a defined supporting-text measurement.
22 scenes cover seven admin sections, four personal settings tabs, audio,
channel/DM, search, quick jump, archive, files, mentions, prejoin/dock/share.

## Reproduction and intermediate checks

Initial audit: 44 captures, plus three expected failing behaviour checks on old
copy. Corrected fixture-only role/session schemas before the accepted baseline;
generated selectors now use valid CSS paths. `.out/issue343/before-final/` is
the accepted Before source. A separate hint regression on the visible compact
overflow trigger failed because no keyboard tooltip existed. The original hint
test selected a desktop-only hidden search action at 390px; that locator mistake
was corrected before implementing hints. Updated joining SSR expectations also
failed before implementation.

First After run: 46 passed, 2 failed. One was an over-specific native-select
label locator, corrected to assert the actual select's accessible name. The
other exposed the unchanged inactive search-tab aria-controls defect, owned by
#340 / open PR #355. No tab/layout work is duplicated here. Full-panel search
axe remains a known pre-existing FAIL; the modified search form, instructions
and resulting status are the explicit scoped axe target. This is not a global
accessibility approval. `.out/issue343/after-verified.log`: 48 PASS, 14.4s;
focused copy/glossary/joining unit checks: 8 PASS; production typecheck/build PASS.

## Decisions

| Surface | Before | After / rationale |
|---|---|---|
| Prejoin | Type eyebrow plus long invitation | Remove repeated type; “Подключитесь с микрофоном или слушайте.”; named join/listener actions and roster remain |
| Joining | Live heading plus “Соединение устанавливается.” | One live heading; disabled and revocation rules remain |
| Audio | Obvious intro, activation invitation, device-scope paragraph | Remove invitations; device-scope text in native “О настройках аудио” disclosure |
| Guild | Intro above primary field | Native “О названии гильдии” after form actions; field limits and save/error remain |
| Profile | Same generic intro on each tab | Remove duplicate; tab names, value help, dirty/pending/security warnings remain |
| Search | Enter hint in metadata plus idle invitation | One aria-describedby instruction; explicit Find button; loading/empty/error results remain |
| Channel / DM | Permanent keyboard helper on desktop | Show when composer has focus; aria-describedby and file limit remain; no focusable control hidden in compact footer |
| Share setup | Repeat “Выберите источник и качество трансляции” | Remove idle intro; every capability, picker, target/actual and bandwidth warning retained |
| Other audited screens | Privacy, role consequences, archive/read-only, media freshness, notification/session restrictions | Keep; already hidden copy is not counted as an improvement |

No label is replaced with an unnamed icon. Reviewed action hints follow the
existing accessible action names and render outside clipping containers with
viewport clamping. They support keyboard focus and pointer hover, remain
hoverable, dismiss on Escape/blur, reposition focused hints on scroll/resize,
and clean up on unmount. Pointer-only hints close on reflow.
Only one hint is active across mixed pointer/keyboard input. Native-dialog hints
are placed in the dialog top layer, not behind its backdrop. Normal Escape
handlers still run. Business event handlers/API/ACL/media paths
are not changed.

## First mandatory attempt

The first full run (`.out/local-features/20261016-110901/`) is retained as FAIL.
Its accessibility suite had 109 PASS and one obsolete assertion requiring the
removed duplicate joining sentence. The updated test instead requires the live
heading, absence of duplicate text and both disabled join actions. Its quality
suite exposed a scroll-position assumption tied to the old header height; the
new test explicitly establishes a nonzero scrolled state, verifies the choice
is visible and then requires the exact position to survive selection. Focused
quality regression PASS (1.4s). Neither test was removed to hide an error.

Expanded flows also caught a new hint hidden behind a native dialog's backdrop;
it now lives in the dialog top layer and must be hoverable there. Focused modal,
focus and toggled-label checks: 3 PASS (1.8s). A separate mixed-input RED case
observed two simultaneous hints; a single-active-hint owner fixes it, with a
retained regression and focused GREEN (653ms). All these follow-ups require the
fresh full run below. The first report is not accepted as final source evidence.

## Visual review follow-up

The second automatic run (`.out/local-features/20261016-111619/`) completed all
registered stages, including 60 microcopy cases, with REVIEW_REQUIRED. Manual
inspection rejected its modal hint capture: an existing translateY(0) creates a
containing block, so a fixed child given viewport coordinates was clipped outside
the modal. A strengthened RED measured its right edge at 1258px against an
873px modal bound. The corrected positioner measures the containing-block origin
and clamps inside the modal, while preserving focus during automatic scrolling.
It now requires correct bounds, actual elementFromPoint hit testing, continued
visibility after hover and a viewport screenshot. Focused regression PASS
(925ms); its original-size capture visibly contains “Закрыть”. Earlier blank
modal hint captures are rejected evidence, not accepted by a locator-only check.
The fresh source-bound run below accepts the corrected code.

## Final scoped acceptance

PASS: `.out/local-features/20261016-112457/report.json`, source
`f2dc654e285537c71e72e476956440d1d2f84fc4`, with empty working diff
(`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
All 15 registered Web stages PASS: unit, build, accessibility, control consistency,
conversation disclosures, mentions, microcopy, password generation, quick jump,
archive, responsive shell, screen profiles, search sessions and actual-stack
smokes at 1440px and 393px. The report's automatic REVIEW_REQUIRED state is
resolved by the scoped manual review recorded here; it is not a global UI gate.

The new microcopy suite has 60 passing cases: 44 inventory captures, 14 flow /
warning / keyboard / touch / hint-lifecycle cases, and two real browser zoom
cases covering seven scenes at 200%. The zoom helper verifies outer/layout
width, DPR, root font, CSS zoom and pinch scale independently. Source-size review
covered changed desktop/compact copy, retained privacy/permission/destructive
help, quick jump/archive/files/mentions and both final action-hint captures.
The final modal tooltip visibly says “Закрыть”, stays within its dialog and is
painted/hit-testable after hovering. The compact hint says “Другие действия”.
Zoomed share controls and hints remain usable; expanded audio help remains
available. Tall full-page zoom captures are supplementary, not a claim that all
below-fold content fits on one screen.

Measured supporting-text Unicode code points at 1440px, help collapsed and
composers unfocused (not all UI text; includes scrollable below-fold text):

| Scene | Before | After |
|---|---:|---:|
| Guild settings | 92 | 59 |
| Audio settings | 573 | 482 |
| Channel conversation | 62 | 14 |
| Direct message | 75 | 27 |
| Voice prejoin | 132 | 82 |
| Profile | 121 | 86 |
| Search | 58 | 27 |
| Share setup | 624 | 585 |

The catalogue contains 116 classified rows, 44 Before/After capture references
with SHA-256 hashes, measurement scope and hashes of changed production files.
Mobile text that was already hidden is not counted as a new reduction. The bare
chat fixture preserves the existing header's aside-extension geometry; actual
workspace geometry is exercised separately by the real-stack smokes.

Focused source comparison confirms unchanged business scripts (ignoring only
the new directive import) and unchanged event bindings in all 14 modified Vue
components. Server ACL, API contracts, session logic and media transport were
not modified. Spec traceability PASS: 39 requirements, using the committed
requirement index; the original Windows brief is unavailable on this Mac.

Known pre-existing search-tab overflow and inactive-tab aria-controls remain
owned by #340 / PR #355. Full search-panel axe is not approved here: the new
checks explicitly scope axe to the changed form, its instruction and status;
zoom evidence retains the existing overflow. This does not close #301 or #339.
The screen-profile suite retains one opt-in publisher/viewer numeric baseline
skip; no real SFU capacity, physical-media QoE, native release, or production
acceptance is claimed. No Keychain interaction was needed.

CI runs `test:microcopy` in the normal Web job and retains its synthetic PNG /
JSON evidence for 30 days as `web-microcopy-${github.sha}`. Earlier failed and
visually rejected attempts above remain recorded. Only this final clean-source
run is accepted. Final commits after it update evidence only.
