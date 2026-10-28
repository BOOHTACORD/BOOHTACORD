# TEXT cache eviction loses an uncommitted edit — I240.C9 / I241.C37

**FAIL.** In actual Chromium153.0.8010.12 on Windows11, the current source
TextConversation/TextHistoryList and real owned Go API/PostgreSQL17.6 lose an
unfinished edit when older-page loading evicts that message. Three primary
repetitions fail; two controls pass. A retained earlier complete profile has
the same three failures and two controls.13 nearest native tests pass,0 skips.
The browser controller completes with exit0; the product verdict exits1.

Source072426d60b1c0b1f7e5f66722a0da5faa00b50d7 is bound before the final browser
run.22 selected source/config/test fingerprints match fresh master
8a2cda38bee5a4d8f7988eb4eefbfa176a62c43a. Canonical fix issue141 already owns
unfinished-edit preservation across window updates; it is reused rather than
duplicated. GitHub state/readback is recorded after evidence publication.

| What it protects | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
| Current isolated runtime/source and fixture ownership | `python -X utf8 .out/qa-history-window/preflight.py`; `python -X utf8 .out/qa-history-window/prepare.py` | Windows Docker, actual Go API/PostgreSQL17.6,9 existing private services | Before profile | `environment-before.json`, `fixture-ready.json`: fresh counts, cookie-authenticated API,1,000 rows/500 replies |
| An uncommitted edit survives scrolling and valid cache-window updates | `node .out/qa-history-window/run_browser.mjs` | Actual production Vue components/Pinia stores in headless Chromium; actual protected message API | Before141/I240.C9/I241.C37 acceptance and after its fix | `browser-result.json`:2 controls PASS,3 evicted-editor cases FAIL |
| The acceptance command rejects actual draft loss, including after the target returns | `python -X utf8 .out/qa-history-window/verify_browser.py` | Retained actual browser observations | Before trusting browser-controller success | `semantic-result.json`: FAIL/exit1; controller exit0 is not product PASS |
| Existing bounded-window/index behavior remains executable | argv in `native-runner.json` | Node24.18.0/Vitest5.0.1 | Supplemental closest regression check | `focused-native-result.json`:5 files/13 PASS/0 skips; does not cover this browser draft-loss case |
| Own data/session cleanup and original runtime preservation | `python -X utf8 .out/qa-history-window/cleanup.py` | Actual DB/API/Docker/port checks | After the failing verdict too | Own1,000 messages/2 channels/category/read cursors removed, own session revoked;9 original services/config/starts unchanged, restart0/private/health200 |
| Exact source hashes and both raw log streams remain safe/private | `python -X utf8 .out/qa-history-window/audit_bind.py` | Git objects, actual Docker stdout+stderr and package metadata | Before publication |22 current-master matches; both-stream credential scan PASS; no raw logs, dataset, identities or screenshots exported |

## Reproduction and controls

1. Prepare the owned deterministic recipe of1,000 messages,500 reply references,
   variable multiline heights, fixed timestamps and a private seed CSV. The
   SHA256 in fixture-ready.json binds the exact seed CSV, not an HTTP-response
   serialization. SQL seeds the isolated data; reads/paging use the actual API.
2. Load through the real store/API until500 messages are cached. Edit the newest
   loaded message and type an uncommitted draft. Do not Save, Cancel or Delete.
3. Scroll to the oldest end. The actual textarea retains its exact value and
   focus; virtualization alone keeps it mounted, including outside the viewport.
4. Click the real `Показать предыдущие сообщения` button. The cache remains500,
   while its maximum dataset index changes999→949. The edited row999 is evicted;
   the textarea count changes1→0.
5. Click `Показать следующие сообщения` three times. Actual protected newer-page
   requests restore maximum indices969,989,999. The target returns as a normal
   message, and the editor/draft does not return. This repeats3/3 times.

Controls: with450 cached, the next50 fill the cache to500 without eviction and
retain the exact draft. With500 cached and an edited row that stays in the
next window, paging also retains the draft. All five scroll-only steps retain
the textarea value/focus. No message PATCH/DELETE is sent; all1,000 server
messages remain revision1/not deleted before cleanup. This is loss of a local
uncommitted edit, not deletion of committed server text. Composer-draft loss
is not claimed.

Source explanation: eviction protects the visible history anchor but has no
editing-state input. The virtual-row pin can only address rows still present
in rowIndex; rowIndex drops the evicted edit and clears its local editing pin.
MessageItem's component-local edit controller is unmounted. Restoring the row
creates an ordinary message component. A fix must preserve/recover the exact
draft across eviction while keeping reversible paging and bounded cache/DOM.

## Scope, observations and retained attempts

The fixture mounts the actual TextConversation, TextHistoryList, message store
and edit controller unchanged. Its UI supplies a synthetic layout/profile label;
authentication is a real own session. A real loopback Vite origin4808 proxies
API traffic to the existing canonical18088 origin with canonical Host and
own-fixture Origin translation. No business API response is mocked. This does
not test production Origin policy, a built/deployed bundle or physical/native UI.
No browser permission or security flag is granted/changed.

Observed DOM rows are14–24 and cache at most500 in this one dataset/profile.
One-sided heap/long-task values are retained diagnostics. Interaction durations
include fixed150ms settling and observer overhead; these are not INP, SLO,
before/after performance, memory-leak or complete virtualization acceptance.
Vite reports65 ResizeObserver-loop warning occurrences in the final private
controller log; their cause/production impact is not established. They are
retained as a separate observation, not silently discarded or called PASS.

Attempts1/2 stop before business API execution: the route-fulfilled document's
cross-origin loopback module is blocked. Attempt2 records the exact loopback
policy diagnostic. Attempt3 successfully prepares real API data but its
controller waits for a mobile-only toggle hidden by desktop CSS; no editor
case completes. Their exit1 receipts and exact runner inputs are preserved.
The first complete profile and the final profile use the actual same-origin
source fixture; the final oracle checks exact draft recovery after return too.

The final restored-target screenshot was inspected at1440×1000: the newest
message is normal text/actions with no edit field. Screenshots remain private;
only hashes and observations are exported. A control's editor may be pinned
outside its captured viewport; value/focus assertions provide that evidence.

Full50/500/5k/10k×0/50/100%, missing targets, paired before/after performance,
protected images, search/unread and logout/account/channel changes remain
NOT_RUN in this packet. Previous witnesses keep their own scope. Source/native
or synthetic data does not close Android, production, hosted or media gates.
The original480 criterion texts and74 old cases are preserved; this is case75.
Only I240.C9/I241.C37 become FAIL; QA240/241 remain open.43 consolidation
decisions are untouched. Replay requires a fresh privately prepared owned
packet; guard checks preserve existing receipts and prevent blind reuse.
