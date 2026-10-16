# DW-05 / #344 — compact, accessible guild navigation

State: PASS_SCOPED (#344 Web navigation). Base master `aa264a74c2501dea78b90044fcbf95e68aab64d4`.
Leaf DW-005 depends on T-050/T-020/T-041/T-022/DW-003/DW-004.

The historical private web-tour archive is unavailable here. Only actual current
production Vue components and the matching sidebar structure are measured, with
explicit synthetic data (36 channels, three categories, 32 DMs and voice rosters).
This fixture does not claim authenticated workspace or native/media acceptance.
The independent mandatory actual-stack run remains required.

## Observed defects and test-first reproduction

`.out/issue344/before/`: six viewport inventories (320/390/768/1024/1440/1920,
height 768), each with top, bottom and DM screenshots plus measured geometry.
Seven tests PASS and four expected RED: no keyboard full-name tooltip, nested
voice-roster scrollbar, touch action opacity zero, and axe's keyboard-scroll
violation for the nested non-focusable roster. A separate pre-implementation
768px/480px test RED observed list bottom at 480px against dock y=427px. Manual
source-size 1440/768 review also showed long category labels wrapping into
neighboring rows. These are observed defects, not aesthetic preference claims.

## Changes

Desktop channel minimum height 36 → 32px and category rhythm reduced; 44px touch
hit areas retained, including large touch displays. Long category labels stay
on one line; full channel/category/DM names are available by keyboard focus or
mouse hints without replacing accessible names containing unread/mention counts.
The shared hint directive accepts an optional presentation label and preserves
its existing ARIA-based default and lifecycle. Selected rows gain an inset mark;
connected voice rows show a named check; unread counts/mentions remain explicit.
Favorite shortcuts now retain unread/mention badges too. Desktop DM minimum row height
56 → 48px while online/offline text remains visible. Text enlargement can grow
rows. No topology, favorite/collapse storage, DM selection or ACL behavior changes.

Only the outer navigation list scrolls, including compact voice-roster previews.
The existing open-drawer grid now applies through 1023px, reserving real dock and
account-footer space at tablet widths as well as phones. Secondary actions
remain on hover/focus for fine pointers and painted on touch. No server rail,
new drawer or alternate preference state was added. PR #355 is untouched.

## Intermediate checks

First After: 17 PASS (7.1s). Expanded run: 20 PASS, 1 FAIL; simplifying an opacity
selector lost specificity against an older mobile rule. Restored both scoped
selectors; regression remains in the touch tests. Final mandatory run and
source-size review are PENDING; this record does not close #344 yet.

## First mandatory run and corrections

`.out/local-features/20261016-120300/` is FAIL, not accepted: 13/16 stages
passed, with three failures retained. Accessibility exposed the simplified
legacy shell fixture's missing guild header; its newly visible action overlapped
the close button. Responsive assertions also assumed the old tablet width
contract (320px outer drawer versus 319px inner content with a 1px border).
The fixture now mirrors production header / sibling close / drawer / nav-content /
dock / footer structure, reuses its existing nav-content in the scroll test,
and checks tablet bounds using the same rules as phone bounds. No axe rule or
hit-target assertion was disabled. An intermediate incomplete fixture correction
exposed close-button stacking behind the header; that run was interrupted after
the first reproduced failure and is not acceptance evidence. Focused final
legacy accessibility PASS (1.3s), responsive suite 11 PASS (8.2s).

The actual-backend 1440px journey passed. At 393px a new full-name tooltip
remained after CSS hid its source row, intercepting the navigation button. A
focused RED retained one tooltip after ancestor hiding. The directive now checks
visibility before showing, and observes only trigger/ancestor visibility
attributes while a hint exists; hide/unmount disconnects the observer. This
preserves hoverability and keyboard toggle updates without leaving body-level
hints over the next view. New navigation suite 23 PASS (10.6s), including that
regression. A fresh source-bound full run is still required.

## Visual rejection of the second candidate

The second run (`.out/local-features/20261016-121156/`, source `5f128e02`)
passed unit/build/accessibility/controls and microcopy before being stopped
intentionally for a visual correction. A source-size Before/After mobile DM
comparison showed its new global minimum made ordinary phone rows 48px instead
of the existing 44px. This candidate is rejected, not accepted from partial
green results. A new focused RED measured 48px against the required 44px at
390px; the 1440px/48px case passed. Phone rows now retain 44px while growing for
200% text; desktop rows remain 48px. The final full run includes both regressions.

## Environmental retry

The third run (`.out/local-features/20261016-121528/`) passed both actual-backend
journeys and 15/16 stages. Its screen-profile stage could not start because port
4801 was held by an orphaned Vite from the interrupted second run. PID 54992 had
PPID 1, this worktree's clients/web cwd and the exact expected fixture command;
only that confirmed owned process was terminated. Screen-profile retry: 18 PASS,
one existing opt-in numeric media baseline SKIP (5.9s). No source changed.
The third report remains FAIL; the complete clean run below supersedes it.

## Final source-bound acceptance

PASS: `.out/local-features/20261016-122127/report.json`, source
`09915b193b2b8942d2096746191c8851e8d7c147`, empty working diff
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
Report SHA-256: `e3a3c522014a7a120a2c42b2e46977726a62bc445458910aa365c65287028a85`.
All 16 stages PASS: complete Web unit suite, production typecheck/build,
accessibility, controls, conversation actions, mentions, microcopy, navigation,
password generation, quick jump, archive, responsive shell, screen profiles,
search sessions and actual-backend desktop/mobile journeys (1440px / 393px).
The runner's REVIEW_REQUIRED status is resolved here by scoped visual review,
not a global UI baseline approval. Final changes after this run update evidence
only; the capture manifest records changed production file hashes.

New navigation suite: 25 PASS (10.2s), including all 36 channel selections at
1440×480, last-row reachability at six widths, keyboard actions/full-name hints,
touch hit areas (including 1440px coarse pointer), selection/favorites/collapse
through resize/reload, member ACL presentation, axe without disabled rules,
phone/desktop DM density and enlarged text, and two independently verified
actual 200% browser-zoom cases. Existing microcopy suite: 60 PASS (22.2s).
The two modified navigation Vue business scripts (excluding the directive
import) and all event bindings compare unchanged against base master.

| Measured / observed surface | Before | After |
|---|---|---|
| Desktop channel row minimum | 36px | 32px; can grow for enlarged text |
| Desktop category heading | 36px, long label overflows vertically | 32px, one-line ellipsis and full-name hint |
| Desktop ordinary DM row | 56px | 48px, can grow for text |
| Phone channel / ordinary DM row | 44px / 44px | 44px / 44px retained |
| Scrollable lists inside navigation | outer list + voice roster | outer list only |
| 768×768 list bottom / dock top | 768px / 715px (overlap) | 588px / 588px (reserved space) |
| Phone channel action | opacity 0 | painted, 44×44px hit area |
| Selected / unread / connected | selection mainly background; counts visible | inset selection mark, explicit counts/@mentions, named connected check |

`dw05-navigation-captures-2026-10-16.json` contains six measured viewports and
18 Before/After screenshot pairs with hashes. Component source-size review
covered top/bottom navigation at 320/390/768/1024/1440/1920px, desktop/phone DM
rows, the focused full-name hint and the 200% zoom captures. Last channels stay
above the dock/footer, categories no longer wrap into neighboring rows, status
text remains readable, and long names remain ellipsized with full keyboard/
hover lookup. Retained scroll position when switching sidebar tabs is existing
behavior, not a new state mechanism. The final actual mobile navigation overlay
was also inspected as supplementary workspace evidence; its high-DPR full-page
preview is not physical-device or native acceptance.

Spec traceability PASS: 39 requirements using the committed requirement index;
the approved Windows brief is unavailable on this Mac. API contracts are
unchanged. The pre-existing numeric publisher/viewer baseline opt-in skip remains;
no physical media capacity, QoE, native release or production gate is claimed.
Known search-tab defects remain in #340 / PR #355; #301 and parent #339 are not
closed by this scoped acceptance. Normal Web CI runs the navigation suite and
retains synthetic PNG/JSON evidence for 30 days as `web-navigation-${github.sha}`.
