# Trusted proxy source / repeated XFF — I240.C6 and canonical fix138

**FAIL: conditional handling of repeated X-Forwarded-For fields.** Actual source
`072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, Go API/PostgreSQL17.6/Caddy2.10.0,
2026-10-28 01:29–01:33 UTC. The primary profile and independent literal-HTTP
witness exit1 after completing their controls. Original source/configuration,
production, router and phone are unchanged. Default Caddy controls pass.

| What it protects | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
| Immediate-peer trust, ordered source boundary, IPv4/IPv6, header limits/fallback | `python -X utf8 .out/qa-proxy-source/run_profile.py run` | Windows11 controller; actual own Compose API/PostgreSQL17.6; trusted proxy namespace and two disposable untrusted peer namespaces | Before I240.C6/#138 source-boundary acceptance | `run-result.json`, per-mode results:95/100 PASS,5 FAIL; trusted phase exit1 |
| Default Caddy replaces untrusted forwarding metadata and preserves distinct client budgets | Same primary command | Actual running Caddy2.10.0, mounted unchanged repository Caddyfile, two distinct actual TCP client peers | Before default-Caddy integration claim | `untrustedA-result.json`, `frontA-result.json`, `frontB-result.json`, `directB-result.json`:30/30 PASS |
| Repeated-field failure exists on literal wire, independently of HTTP request encoding | `python -X utf8 .out/qa-proxy-source/run_wire.py` | Literal HTTP/1.1 CRLF requests over private TCP in actual trusted proxy namespace | Before confirming a protocol-level counterexample | `wire-result.json`:18 cases,3 separate-field400 failures;3 equivalent combined controls429; exit1 |
| Existing tests remain executable and invalid trust configuration is rejected | `python -X utf8 .out/qa-proxy-source/run_native.py` | Pinned Go1.26.4 Linux amd64/Cgo race container, plus Windows Go1.26.4 runtime-config test | Before supplemental native/config acceptance | `native-result.json`:18 original race PASS +1 invalid-CIDR PASS,0 skips |
| Focused new tests detect boundary and aggregate-limit regressions | Same native command; exact candidate argv retained | Test overlay on unchanged actual source; Linux race,3 repeats | Before trusting the failure witness or a later fix |3 repeated-field tests fail×3=9; other candidate pass events39 including subtests; no race reports; exit1 |
| Actual trust/perimeter configuration matches declared test roles | Primary audit-config phase | Running private Caddy admin config, mounted file, Docker network/ports and API trust setting | Before interpreting HTTP source behavior | `config-audit.json`: one proxy identity/32, two distinct untrusted peers, API/admin unpublished, running config matches file |
| Data, source, services and configuration remain correct after a failing profile | `python -X utf8 .out/qa-proxy-source/verify_after.py` | Actual PostgreSQL/API/Docker, both bounded log streams | Before publishing failure/cleanup | `environment-after.json`: unchanged DB/config,9 services/restart0, helper containers0, health200 |

## Confirmed differential counterexample

Roles only: P is the configured trusted proxy, B is the nearest untrusted hop,
A is an earlier untrusted address. Exhaust B with ten malformed login requests.
The next normal B request returns429 RATE_LIMITED with positive Retry-After.

From immediate peer P, send these two field lines:

```http
X-Forwarded-For: A
X-Forwarded-For: B, P
```

The API reaches malformed-body validation400; changing A gives a fresh source
budget. The same ordered chain in one field (`A, B, P`) returns429. This repeats
3/3 in the primary client and3/3 with separately written literal TCP bytes.
The protected B budget still refuses429 after those pairs. Private raw requests
are retained with digests and exact field-line counts; their source values are
excluded from public evidence.

The current `sourceKey` reads `request.Header.Get("X-Forwarded-For")`, so it
examines only the first field value. Later field lines do not contribute their
nearest-untrusted boundary, byte count or hop count. Additional primary cases
confirm separate-field aggregate4152-byte and33-hop inputs reaching400, while
their same-order combined controls fall back to the exhausted peer429.

The expected combined-chain control is based on the original138 acceptance of
multivalued headers and ordered HTTP field combination. [RFC9110 §5.2–5.3](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.2)
defines combining repeated list field values in order. The application-specific
source-boundary interpretation is explicit; the observed status differential
is independently measured. A fix may process all ordered values with aggregate
bounds, or specify safe rejection/fallback for repeated fields. Preserve peer
trust, independent budgets and the existing Caddy defenses; rerun all witnesses.

## Passing controls and limits

An untrusted direct API peer cannot reset its10/300s budget by changing XFF,
adding repeated fields, X-Real-IP or Forwarded. The same exhausted peer through
Caddy still receives429. Another actual peer through the same Caddy receives
ten400 admissions before429, and direct access afterward shares that exhausted
budget. This verifies real distinct-client keys across the Caddy→API boundary.
The tested default Caddy path sanitizes incoming forwarding metadata; a public
default-Caddy bypass is **not established** by the conditional trusted-peer bug.

Single-field nearest-untrusted stopping, malformed data within/outside the
trusted walk, missing/empty headers, IPv4-mapped IPv6, expanded IPv6, exact4096
versus4097 bytes and32 versus33 hops all pass their controls. Native variants
also check logical multiple trusted CIDRs and empty trust; malformed CIDR load
is rejected. Header chains are controlled inputs, not physical multiple-proxy
network acceptance. Malformed one-byte login bodies stop before account/KDF;
400 demonstrates rate admission, not credential authentication or ACL bypass.

The combined118 actual requests produce84 parser400 and34 rate429 responses,
matching server aggregate counters. KDF work/account admission/store saturation
deltas are0. DB counts remain516 users/2065 session rows/50 unrevoked rows/
9 attachments; no users, sessions or files are created. Both own peer containers
are removed, all original nine services remain running/restart0 and host ports
remain loopback. API and Caddy admin have no host publication.

The pre-existing QA Compose uses one owned bridge with outbound access
(`Internal=false`); it is not a full reproduction of default Compose network
topology. All nine initial network members belong to this QA project. Tests use
only fixed own API/proxy endpoints. `preflight1/` retains an initial controller
exit1 before HTTP/config/helper creation: the controller had incorrectly assumed
an internal Docker network. Actual topology was audited without changing it.

`source-binding.json` binds selected exact source/config/tests to the image and
a fresh master snapshot. Original pre-execution hashes and public LF-copy hashes
are distinct. Config values, source IPs/keys, raw requests/service logs, cookies,
credentials, binaries and caches remain private. Existing local fixture/common
runner provisioning is required for replay. The duplicate search reuses138's
original multivalued-header scope. I240.C6 and QA240 remain FAIL; no43 test
consolidation decision or physical/platform/media/hosted gate is completed here.
