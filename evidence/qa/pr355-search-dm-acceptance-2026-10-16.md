# PR #355 — DW-01 / DW-02 final acceptance

State: PASS_SCOPED for #340 and #341. Base master
`86ce6458062698c1b2727724ce8313c9b6ecd386`; original PR head
`11a1414e0ebe2b4983a98df3c054327a0d2fa110`. Current master merged while
preserving DW-03…06 and their registered scenarios. Dependencies T-041/T-050 read.

Search modes wrap into a grid without hidden horizontal controls. The heading and
tab controls stay available while results scroll. Switching through shorter modes
retains the message-result position, query, scope and filters; a fresh query starts
at zero. The native top-layer DM dialog contains focus and returns it on dismissal,
wraps long names and preserves the current DM/draft on cancellation. API/ACL
contracts unchanged.

Tests were added before the scroll fix: both 390/1440px cases failed first because
the tab bar was offscreen, then because a sync watcher restored before DOM update
and clamped the rail to zero. A pre-flush watcher waits for the actual DOM update;
scroll events outside the message mode do not overwrite its saved position.
Failed logs remain in `.out/pr355/search-before.log`, `search-after.log` and
`scroll-debug.log`; final `search-final.log` passes.

Validation: 472 unit files / 1533 tests PASS; production build PASS; search browser
22 PASS, DM picker browser 20 PASS. Actual browser zoom 200% independently measured
in windows 640/780/2048/2880px (CSS 320/390/1024/1440): DPR2, root16px, CSS zoom1,
pinch1 and physical PNG width asserted. Root text 200% is a separate scenario.
Geometry, keyboard/Shift+Tab, all four modes, long labels, focus, axe, retry,
pagination, single open, pending cancellation, fresh ACL and Back retention pass.

Mandatory clean-source run `.out/local-features/20261016-151737`: all 19 stages
PASS for auth/shell/chat/admin/settings/voice/screen on Web. Exact source
`3ba2eeed77b2ff3d20789b50987952d210b7e3f8`, empty diff hash recorded. Actual
isolated API/PostgreSQL/LiveKit/Tempo lifecycle passes at desktop1440 and touch393;
both report all four modes, zero horizontal shift, query retention and native DM
modal/focus return. Owned resources removed. Spec traceability PASS: 39 references,
committed index only because the approved Windows brief is unavailable here.

Visual review: selected Before/After, zoom and live-server frames were inspected
at original resolution for relevant controls, with whole-viewport overviews.
Fresh Before uses all Web production sources exactly matching current master;
three temporarily replaced files were restored byte-for-byte in finally. Search
clips the right tab and the old DM picker intersects the sidebar on 320/390/1440.
After: all tab labels and focus outlines fit; the modal is bounded, names wrap,
close remains reachable and the long list scrolls independently. Actual touch
archive/mentions/pins and desktop mode context remain readable. No baseline was
approved. The companion JSON lists 30 selected source frames with sizes/hashes,
8 zoom metrics and the immutable run-report hash. Generated images stay local;
GitHub CI retains the new search/DM browser artifacts for 30 days.

The automated report stays REVIEW_REQUIRED; this evidence supplies scoped manual
PASS for DW-01/DW-02 only. Historical 15 October PARTIAL records remain unchanged.
The private original source tour is unavailable; fresh current-master reproduction
replaces it for this fix. Full epic #339 / release gate #353, native applications
and physical media QoE remain NOT_RUN. Final GitHub checks are recorded on PR #355.
