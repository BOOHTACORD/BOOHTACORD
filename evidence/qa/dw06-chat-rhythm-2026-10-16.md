# DW-06 / #345 — continuous TEXT/DM history

State: PASS_SCOPED (Web implementation and local acceptance; final GitHub CI/merge recorded in linked PR). Base master `efdb4b04597d5f0a130b3b3f1a19ce17b9b1becb`.
Leaf DW-006, dependencies T-040/T-041/T-044/T-050/DW-003/DW-004.
The private historical web-tour archive is unavailable; only observed current
production components and new synthetic fixtures will be measured. Original
screenshots are not claimed as reviewed. Existing grouping/actions/composer
state mechanisms must remain unchanged. Final source-bound Web real-stack
acceptance, scoped visual review and CI remain required.

## Candidate and red-first checks

The approved leaf dependencies were read. Tests were written before source edits:
`before-valid.log` has 6 inventory passes and 4 expected behavior failures (missing
full accessible timestamps, permanent six-button palette, DM grouped margin 24px).
The first fixture attempt had DM setup/schema mistakes; those were fixed in the
fixture and remain recorded as failed attempts. `unit-before.log` also records
missing timestamp formatter and old 24/34/25px gap assertions failing.

Production changes are presentation-only: original grouping and conversation
state/action/request controllers remain intact. History gap policy and DM CSS now
agree (4px continuation; 12px desktop/10px narrow ordinary boundaries; 16px day
boundary and 12px after it). Grouped time is painted in a rem-sized avatar gutter;
all message clocks expose local date, seconds and timezone via aria-label/title.
The native reaction disclosure keeps positive counts outside the closed palette,
six stable palette buttons, permission-gated pin slot and visible load/errors.
A long code block discovered by axe now has keyboard focus and a named region.

Focused candidate: 21 browser cases PASS after fixture synchronization corrections,
including actual 200% browser zoom (window 780/1440, layout 390/720, DPR2, root16px,
CSS zoom1 and pinch1), image viewer, owner actions, memory-only drafts on remount,
Shift+Enter/Enter and synthetic IME guard, 1,000-row bounded TEXT DOM, new-message
jump and older-page anchor in TEXT/DM. Page reload intentionally clears the existing
memory-only drafts; no persistence policy was changed. TEXT-only system welcome
is not claimed as a DM message kind. Physical IME/reader/media behavior is not
proved by these component fixtures.

The full unit run initially caught a date-divider test counting newly added
accessible timestamp labels as dividers; the assertion now counts date-divider
markup explicitly. A transient virtual-row remount required polling the final
anchor geometry rather than dereferencing a momentary absent node. The existing
virtual engine can emit ResizeObserver undelivered-notification warnings during
synthetic bulk replacement; no virtualizer mechanism was changed.

## Final local acceptance and visual review

Clean app candidate `2cb8bdc05a2e8e697c682e0561276b216c332b7a` passed all
18 registered Web stages, including build, 472 unit files / 1,533 assertions,
110 accessibility cases, action disclosure, social requests/ACL/recovery,
search-session retention, navigation, and actual protected API/SSE/SFU lifecycle
at 1440 and 393 CSS px. Owned actual-stack resources were removed. The aggregate
report remains `REVIEW_REQUIRED` by design; this record supplies scoped visual
review. Mandatory command:

```sh
./tools/qa/local_features/check.sh --feature auth --feature shell --feature chat \
  --feature admin --feature settings --feature voice --feature screen \
  --platform web --base efdb4b04597d5f0a130b3b3f1a19ce17b9b1becb --real-stack
```

Report: `.out/local-features/20261016-135848/report.json`; all stage statuses
and source/diff hashes are copied to the adjacent JSON manifest. Traceability
PASS: 39 requirements, committed index only (approved Windows brief unavailable).
No contract changed. Native/physical IME, media capacity and global #301/#339
acceptance are outside this Web leaf. No approved screenshot baseline was replaced.

Reviewed original-file captures at 320/390/1440 for TEXT and DM, attachments,
RTL/long URLs/code/emoji, keyboard reaction disclosure and count state, image
viewer, deleted/edit/reply/system boundaries and four actual-200%-zoom cases.
The message body stays in the viewport; long code scrolls within its focusable
region. Date/unread boundaries, start-of-group author, repeat clocks and hover/focus
actions remain distinct. Long attachment filenames wrap; the full image is visible
in the protected viewer and Escape returns focus. Existing compact composer stays
52px TEXT desktop / 54px narrow / 58px DM desktop in this fixture.

One initial 1440px virtual-history capture contained a partially painted frame
while its DOM/geometry assertions passed; it is explicitly rejected in the manifest.
An unchanged-source recapture was complete. The final capture helper waits for
image decode plus two paint opportunities after scroll, and all 21 focused browser
cases were rerun PASS (`.out/issue345/final-review.log`); the final 1440 capture was
reviewed again. This and the tracing-fixture locator adjustment are test-only changes
after the clean-source gate; `clients/web/src` is identical to the app candidate.
The optional tracing relay/Tempo scenario is NOT_RUN (one explicit skipped case
without its external QA environment); the adjusted locator preserves its metadata
readiness assertion for the now-collapsed palette. It is not claimed as new telemetry
acceptance.

Measured 12-message synthetic history, same bodies/attachment geometry and viewport:

| CSS width | TEXT height before → after | DM height before → after |
| --- | ---: | ---: |
| 320 | 2859 → 2270px | 3047 → 2290px |
| 390 | 2527 → 1918px | 2775 → 1998px |
| 1440 | 1758 → 1606px | 1827 → 1583px |

At 1440, ordinary group gap is 24→12px; grouped TEXT stays 4px and DM becomes
24→4px after removing its overriding selector. At 390 the second grouped row's
content height is TEXT 126→72px, DM 122→68px. TEXT row rectangles include virtual
padding; DM rectangles exclude CSS margins, so row heights are compared within
each client only. These measurements are readability evidence, not capacity claims.
Actual-stack captures confirm message/date/unread content and permissions on the
running application; they do not close unrelated search-panel or native-client tasks.

The JSON manifest records Before/After/actual-stack PNG dimensions and SHA-256,
plus scenario hashes; generated images remain outside Git. Normal Web CI now runs
`test:chat-rhythm` and `test:message-social` and retains `web-chat-rhythm-*` evidence
for 30 days. Final PR CI status/artifact URLs must be checked before merging/closing
#345; no production deployment is implied.
