# Issue 689: R1 Web protected recovery

Status: **PASS_SCOPED**. This closes the Web protected-HTTP recovery subcase,
not the complete multi-platform R1 or issue 689.

## Source and defect

- Current master baseline: `32825c9b8ed4ae24dbf3747b063f929f79fe2c44`.
- Tested clean implementation: `c06c8a0fe24a6c944cb91d90f2487ef14f30cad3`.
- Production workspace recovery reused a coalescer across socket incarnations.
  A held old topology GET prevented the new recovery from finishing. The
  regression failed before the fix: expected two requests, observed one.
- Each socket now owns its recovery gate. Topology refreshes use request epochs
  and socket admission to reject late success/error and preserve newer loading.
  Same-socket coalescing, cursor/replay, ACL and media behavior are preserved.
- Text/DM history and navigation, notification follow-ups, permission recovery
  and authenticated-store disposal were reviewed at their existing owner edges.
  Full recovery now requests a fresh permission generation.

## Focused verification

| Check | Result |
| --- | --- |
| Nearest Web realtime/workspace/roster/topology tests | 140 PASS |
| Full Web unit suite before serialization follow-up | 2031 PASS (historical) |
| Post-master-sync focused Web regressions | 18 PASS |
| TypeScript and production Web builds, Windows and Linux | PASS |
| Flutter realtime/roster tests, pinned 3.47.7 SDK | 97 PASS |
| Go coordinate_roster tests | 18 PASS, zero skipped |
| Owned control HTTP tests | 2 PASS |
| Client parity, no-SSE migration guard, signal catalog check | PASS |

The 2031-test full Web run predates the live-owner serialization follow-up;
it is historical, and final required CI is tracked in PR 837. The 140 nearest
tests and real-stack run cover the final implementation. Flutter/Go production
inputs are unchanged; Flutter tests are not installed-client/native acceptance.

## Real stack and visual observations

Command: `python3 -m tools.qa.realtime_recovery.run`, native Linux Node/Chromium,
production Web build, isolated real Go API/PostgreSQL/LiveKit/Caddy. Dedicated
ports and an authenticated loopback control own only their exact QA namespace.
CLI exit: **0**, including ownership-checked cleanup. The runner builds Web and
checks source identity before/after. Sanitized results and artifact hashes are
in the adjacent JSON; original screenshots remain ignored under `.out/`.

- An independent peer populated the observer's roster through real SFU/socket
  transport. An actual topology response was held across socket replacements.
- A real server resync was requested with an unknown reconnect cursor; socket
  frames were not fabricated. The peer left and a new text channel was added.
- The replacement showed an empty roster and fresh topology before releasing
  the old response; repeated probes found no restored participant afterward.
- The owned API process was restarted. Reconnection used a changed server
  generation. The final assertion waits for the maintenance banner to hide
  and the channel header to show fresh empty state before taking the capture.
- An old account recovery was held; logout/login to a synthetic member happened
  in the same page without reload. Releasing the previous account's response
  did not change the member identity or restore the departed participant.
- Five screenshots were reviewed at 1440x960 source resolution. The populated
  view shows one peer; subsequent views show none, with the fresh text channel
  retained. After account switch the footer shows the member identity. Labels
  are readable and no relevant clipping or ghost participant was observed.

## Serialization follow-up discovered during acceptance

Pre-follow-up hosted CI 44890836212 failed lifecycle at the retained stage
`critical-burst-hidden-channel-selected`; the public frame did not retain the
inner burst assertion. A focused local run of the unchanged original burst
controller reproduced a real candidate defect: burst50 had two concurrent
topology GETs when UI and socket scopes overlapped. Two new unit regressions
failed with two requests instead of one. Live UI reads now share the admitted
socket owner; a closed socket still cannot block the replacement.

The same original real-stack burst controller now passes series 1/20/50:
maximum parallel topology/history GETs are one, hidden history reads are zero,
and old-page edit/delete plus ID-only hint behavior pass. CLI exit 0 includes
owned cleanup. The full R1 process-restart/account-switch scenario then passed
again on the final clean immutable implementation, recorded in the JSON.

The visual review caught an earlier restart capture taken during transient
restoration. The final QA-only follow-up explicitly waits for fresh UI; its
clean runtime reports `api_fresh_ui: true`. No product source changed after the
140-test and burst-controller follow-up.

## Wider gate and limits

The overlapping broad local-feature run is **FAIL/INTERRUPTED**, not accepted:
its first Linux build lacked a lockfile platform dependency; accessibility had
5 failures/110 passes and header actions 1 failure/12 passes. Connection-status
passed 10 cases. It was stopped at unrelated microcopy coverage. The missing
build dependency was installed and the final focused Linux build passed.
Targeted Windows comparisons on baseline and candidate passed all nine selected
accessibility cases and the 390px header case. These comparisons do not turn the
failed wider Linux gate green. Logs remain `.out/local-features/20261121-115404`.

No physical media/quality/capacity claim is made. Installed Windows/Android/Apple
runtime, wider multi-platform R1 acceptance and separate R7/R8 gates remain open.
Required PR CI, merge and current-master results are tracked on issue 689.
