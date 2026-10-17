# DW-13 — Web context headers and actions (#352)

PASS for this Web implementation scope on 2026-10-17 (Europe/Istanbul).
Accepted clean source `cb3e1d3ca2d65834a91d75d1b4b0bb08bf13d8e6`; base master `8f4b15a6ffb0d29389ecf45189be147b2f708227`.
Leaf DW-013 uses T-050/T-041/T-022 and DW-003/004/007/011/012.

## Contract and surfaces

| Surface | Object and topic | Primary and secondary actions |
| --- | --- | --- |
| TEXT | Full accessible channel name; one-line optional server topic | Search, members, existing overflow/files |
| DM | Full accessible peer name; dialog type | Search and existing overflow/files; no guild member panel |
| VOICE | Selected room name and current status | Search linked to actual external panel, members and overflow |
| Profile/audio/admin | Existing full and compact settings titles | Shared navigation/action group and labeled close X |
| Global/local search and files | Existing panel title and state | Same ghost X icon contract; local search/files now have explicit labeled close |

Object/topic shrink before the fixed primary actions; topic is hidden at narrow
widths. Shared tokens keep 36px desktop and 44px narrow/coarse targets. Names
remain complete in the accessibility tree and title disclosure. Decorative
TEXT/DM symbols use fixed SVGs so root text200 cannot overrun their icon slots.
Action hints work on hover and keyboard focus. Expanded nav/search/member/menu
states are truthful; navigation precedes primary actions in keyboard order.

The existing WorkspaceHeaderActions and named overflow slot are reused; no new
boolean-heavy header abstraction. Overflow retains search/files/member access,
opens with ArrowDown/ArrowUp and preserves arrow/Home/End/Escape behavior. Files
focus their title on opening and return focus to their own overflow trigger on
close/Escape. Local search returns focus to its search trigger. Close and the
existing protected-context Back remain separate. No destructive action moved
into a header, and existing confirmations/ACL remain authoritative.

## Verification

- 1570 Web unit tests, 474 files; Vue/TypeScript production build PASS.
- 13 focused browser cases: seven production-component surfaces at
  320/390/768/1440; axe, keyboard hints/menu/focus, linked expanded controls,
  state preservation, root text200, and independently verified native browser
  zoom200 in 640/1440 windows (DPR2 with root font16px, no CSS/pinch zoom).
- Complete local gate `.out/local-features/20261017-144355`: 24/24 stages verified with one complete same-source integration retry,
  including 20 registered browser configurations and actual API/SFU clients at
  desktop1440/DPR2 and touch393/DPR3. This is a composite acceptance: raw gate
  has 23 PASS and one FAIL at mobile lease-notification timeout (pending kick
  hint, oldest pending21s, connected transports0). The entire failed mobile
  stage passed on identical clean source in `.out/issue352/actual393-retry/393`.
  No timeout/assertion changed. Raw gate remains FAIL and visual_review NOT_RUN. Selected manual review is separately recorded.
- 35 exact-base-master Before header captures, 49 final header captures and
  header regions from 14 actual browser-zoom frames plus one keyboard-return
  frame inspected at source resolution. Unchanged final frames are checked by
  SHA256 against reviewed captures. No private original Tour frames or new
  pixel/golden baseline approval is claimed.
- Actual owned TLS Go API/PostgreSQL/LiveKit: TEXT/DM search state/link,
  keyboard overflow, files title focus and correct trigger return, same selected
  conversation and retained typed draft; VOICE search/navigation-mode close
  with the same selected room and RTCPeerConnections. All 12 acceptance flags
  PASS at both widths; existing settings/profile, ACL, persistence/restart and
  owned-resource cleanup gates also PASS. No request/response mocks.
- Fourteen selected actual header/menu/search/settings image regions reviewed
  using source-pixel crops. JSON includes source, report/image/crop hashes and
  exact crop rectangles. Screens contain owned synthetic accounts only.
- Traceability PASS for 39 committed requirements. Approved Windows brief is
  unavailable on this host; no new server/wire/media contract changed.

## Earlier findings and scope

Focused tests failed before implementation for expanded navigation naming,
VOICE search state and keyboard hint on navigation-search close. Large-text
review then found the literal-symbol overflow, covered by a failing-first test
and SVG correction. One complete run had 23/24 passing stages: a mobile QA
selector matched two correctly labeled navigation closes. Its intended drawer
was scoped explicitly. A subsequent 24/24 run still failed selected visual
review because the navigation-search X inherited pill styling. A separate red
style assertion preceded the CSS fix. Prior raw FAIL/partial/visual findings
remain preserved; acceptance uses the final clean-source run above.

This changes Web header presentation and action accessibility. Existing
navigation stores/route state, secure cookies/Origin/CSRF, server ACL and DM
privacy, media transport and native clients remain independent. Synthetic
browser media proves session continuity here, not hardware capture/audio
quality or capacity. Physical screen-reader and native acceptance are NOT_RUN
for this Web issue; no production deployment or broad release GO is claimed.

Fresh final-head CI artifacts and exact-tree merge/closure receipts are linked
in the PR before the issue is completed. The JSON record is the detailed local
source-bound receipt; screenshots are retained as CI artifacts, not committed.
