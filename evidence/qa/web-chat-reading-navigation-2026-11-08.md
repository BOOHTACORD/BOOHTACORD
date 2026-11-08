# Web chat reading and navigation QA — 2026-11-08

## Scope

- The first unread message advances the read cursor only after it intersects the visible message viewport. Opening a conversation no longer shows the unread banner/context panel.
- Search results open in the normal channel or DM history and briefly highlight the target. Search navigation preserves the user's position while history pages and virtual rows resize.
- Sending a message follows the new message into view in channel and DM conversations.

## Checks

- Focused Web unit tests: 6 files, 21 tests passed, covering read visibility, follow-latest anchoring, history pagination and unread presentation.
- Registered Web feature acceptance: all selected Web suites passed, including unit tests, production build, accessibility/browser suites, and authenticated real-stack journeys at 1440 px and 393 px.
- Next-client acceptance against owned PostgreSQL, API and LiveKit: limited and unlimited capacity profiles passed. Channel and DM unread-cursor SQL checks passed; search opened a historical channel target in the normal list without advancing the unread tail; voice lease stayed unchanged; foreign DM ACL remained enforced. Owned services were removed after the run.
- `pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1`: passed; 39 requirements referenced. The approved product brief is unavailable on this host, so validation used the committed requirement index only.
- `git diff --check`, JSON parsing and `node --check` on changed QA scripts: passed.

## Visual review

Reviewed generated screenshots at source resolution:

- `.out/local-features/20261108-143104/images/web-real-stack/1440/global-search-result-in-conversation.png` (2880 × 1800): target row is centered and visibly highlighted in normal channel history; no context panel is present; surrounding messages and composer remain visible.
- `.out/local-features/20261108-143104/images/web-real-stack/393/dm-search-result-in-conversation.png` (1179 × 2556): DM result is highlighted and in the message viewport; no context panel is present. The conversation is short, so the remaining history area is empty as expected.
- `.out/local-features/20261108-143104/web-accessibility/accessibility.browser-dire-bb6cf--result-in-the-conversation/search-result-in-conversation.png` (390 × 844): same target-in-history behavior at the browser test viewport.
- `.out/next-client-acceptance/search-target-voice-retained.png`: the old channel result is visible and highlighted, the search panel is closed, and the voice session remains connected.
- `.out/next-client-acceptance/unread-direct_message.png`: normal history is at the read tail without the unread banner/context panel.

No screenshot baseline was approved. The local feature runner therefore retains `REVIEW_REQUIRED`; the scoped screenshots above were visually reviewed and observations recorded here.

## Limitations

- This acceptance covers Web behavior and local owned-service integration. It makes no claim about native clients or production deployment.
- Existing Vite warnings about the LiveKit chunk and bundle size remain outside this change.
