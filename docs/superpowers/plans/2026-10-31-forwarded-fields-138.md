# Ordered Forwarded Fields #138 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all ordered X-Forwarded-For field values within the existing 4096-byte/32-hop bounds, preserving the immediate-peer trust boundary and limiter policy.

**Architecture:** Keep the existing source.go leaf and right-to-left nearest-untrusted walk. After the existing untrusted-peer early return, bound the field count and combined byte count before joining Header.Values with commas; keep the existing total-hop and malformed-hop semantics. No new production abstraction, trust configuration, quota, window, store capacity or API contract is needed.

**Tech Stack:** Go1.26.4 net/http, existing ratelimit package, native race/JSON tests; root-owned isolated API/PostgreSQL17.6/Caddy and independent literal HTTP1 witness for acceptance.

---

## Operating brief and preservation boundary

- Route/packet: review_gate, backend/internal/security/rate_limit/source.go; SEC-001, REQ-SECURITY-01/login ingress. Native edge: Limiter.Middleware -> sourceKey; Config.TrustedProxyCIDRs -> parseTrustedProxies. SEC-001 dependencies T-010/T-012/SEC-002/SEC-004 remain unchanged.
- Exact baseline: 4a0f2582d58e521fa79d4905d124345185138b54, read-only in C:/Users/egkur/.codex/worktrees/upload-read-deadline-134/BOOHTACORD. Create the future implementation worktree on codex/forwarded-fields-138; do not implement in the Android QA or #134 release worktree. This planning packet changes only this document; no staging/commit or runtime execution.
- Files: modify backend/internal/security/rate_limit/source.go; create source_fields_test.go and source_limits_test.go in the same package. Existing source_test.go, middleware_test.go, limiter_test.go and config/runtime/load_test.go are preservation checks, not rewrite targets. Target production file<=100 lines, hard120; both new test files<100 lines. One production file/two tests; no needless split.
- Preserve untrusted-peer/unknown RemoteAddr early returns, IPv4/IPv6 normalization, all-trusted walk, malformed hop inside trusted walk -> peer, malformed hop left of a reached untrusted boundary -> ignored. Preserve native login source10/300s, max-source/capacity behavior, CIDR validation, Caddy sanitization and unpublished API/admin topology.
- Immutable counterexample: e2dac43964b65abc33393a4fa02d0fd722057dc4/evidence/qa/open-issues-2026-10-27/isolated-proxy-source/README.md. Its actual0724 profile was95/100 and literal-wire15/18, with original18 race PASS events plus invalid-CIDR PASS. This proves a conditional trusted-forwarder defect, not a public standard-Caddy bypass.
- Root's fresh4a0 native preservation/RED receipt: A/.out/issue138/baseline-native-attempt1/result.json SHA25612603e249e495e700e80e11698f05a7bc300b9080c00eeed17b5c62762ea3274. Windows Go1.26.4 existing tests/count3:18 PASS/0skip; unchanged old candidate overlay: the three named repeated regressions fail3times each,39 variant/subtest PASS/0skip. Checkout source.go CRLF SHA256f2acf749674bab5f5d67588c877573dd6b65c44d919481c944c7b5ba8a87006c. Root ran this independently; it does not replace RED execution of the new exact-edge tests below or actual API/Caddy acceptance.
- Read-only recipes: C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD/.out/qa-proxy-source/{resolver_repeated_test.go,resolver_variants_test.go,probe_*.go,wire_witness.go,run_profile.py,run_wire.py,run_native.py}. Never edit/re-execute these historical runners: they bind old0724/old fixture and run_wire.py explicitly expects FAIL. Root adapts the matrix in a separate bounded QA packet after this plan handoff.
- Stop condition: focused RED -> minimal GREEN -> pinned native/regression and meaningful mutation evidence -> root's fresh source-bound API/Caddy plus literal-wire matrix -> cleanup. Any skip, unexpected429, source/config mismatch or controller failure stays FAIL/BLOCKED. No production requests, trust expansion or limiter resets to obtain PASS.

## Task 1: Retain ordered-field and malformed-boundary regression tests

**Create:** backend/internal/security/rate_limit/source_fields_test.go.

- [ ] Write the complete file below before changing source.go. Synthetic documentation addresses are intentional; no runtime addresses or user identifiers belong in tests/evidence.

```go
package ratelimit

import (
	"net/http"
	"strings"
	"testing"
)

func sourceFromFields(t *testing.T, remote string, fields []string) string {
	t.Helper()
	trusted, err := parseTrustedProxies([]string{"10.0.0.0/8", "2001:db8:1::/48"})
	if err != nil {
		t.Fatal(err)
	}
	request := &http.Request{RemoteAddr: remote,
		Header: http.Header{"X-Forwarded-For": fields}}
	return sourceKey(request, trusted)
}

func TestSourceKeyRepeatedFieldsNearestBoundary(t *testing.T) {
	fields := []string{"203.0.113.9", "192.0.2.9,10.0.0.4"}
	for _, values := range [][]string{fields, {strings.Join(fields, ",")}} {
		if got := sourceFromFields(t, "10.0.0.5:443", values); got != "192.0.2.9" {
			t.Fatalf("source = %q, want nearest untrusted boundary", got)
		}
	}
}

func TestSourceKeyOrderedFieldsMatchCombined(t *testing.T) {
	cases := []struct {
		name, remote string
		fields       []string
		want         string
	}{
		{"missing", "10.0.0.5:443", nil, "10.0.0.5"},
		{"empty", "10.0.0.5:443", []string{""}, "10.0.0.5"},
		{"all_empty", "10.0.0.5:443", []string{"", ""}, "10.0.0.5"},
		{"leading_empty", "10.0.0.5:443", []string{"", "192.0.2.9"}, "192.0.2.9"},
		{"trailing_empty", "10.0.0.5:443", []string{"192.0.2.9", ""}, "10.0.0.5"},
		{"trusted_walk_bad", "10.0.0.5:443", []string{"192.0.2.9", "bad-ip,10.0.0.4"}, "10.0.0.5"},
		{"ignored_bad_left", "10.0.0.5:443", []string{"bad-ip", "192.0.2.9"}, "192.0.2.9"},
		{"all_trusted", "10.0.0.5:443", []string{"10.0.0.3", "10.0.0.4"}, "10.0.0.3"},
		{"ordered_boundary", "10.0.0.5:443", []string{"192.0.2.9", "203.0.113.9"}, "203.0.113.9"},
		{"IPv4_mapped", "10.0.0.5:443", []string{"::ffff:192.0.2.9", "10.0.0.4"}, "192.0.2.9"},
		{"IPv6_normalized", "10.0.0.5:443", []string{"2001:0db8:abcd:0000:0000:0000:0000:0001", "10.0.0.4"}, "2001:db8:abcd::1"},
		{"two_trusted_CIDRs", "[2001:db8:1::5]:443", []string{"192.0.2.9", "10.0.0.4"}, "192.0.2.9"},
		{"untrusted_direct", "192.0.2.4:443", []string{"203.0.113.9", strings.Repeat(" ", 4097)}, "192.0.2.4"},
		{"invalid_peer", "not-address", []string{"192.0.2.9", "10.0.0.4"}, "not-address"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			for _, fields := range [][]string{tc.fields, {strings.Join(tc.fields, ",")}} {
				if got := sourceFromFields(t, tc.remote, fields); got != tc.want {
					t.Fatalf("source = %q, want %q", got, tc.want)
				}
			}
		})
	}
}
```

- [ ] From the future worktree backend directory run `go test -json -count=1 -run '^TestSourceKey(RepeatedFieldsNearestBoundary|OrderedFieldsMatchCombined)$' ./internal/security/rate_limit`. Expected RED on the untouched4a0 source: nearest repeated-field boundary and split-versus-combined malformed/empty variants differ. A build error is not the expected RED.

## Task 2: Retain aggregate bounds and their exact accepted edges

**Create:** backend/internal/security/rate_limit/source_limits_test.go. It uses sourceFromFields defined in Task1.

- [ ] Write this complete file before the fix. Both byte-test fields are individually<=2048 bytes; failure cannot be attributed to one oversized field. Padding is internal between an existing comma and a trusted IP, not outer field whitespace that net/http legitimately trims.

```go
package ratelimit

import (
	"fmt"
	"strings"
	"testing"
)

func TestSourceKeyRepeatedFieldsAggregateBytes(t *testing.T) {
	const client, peer, proxy = "192.0.2.9", "10.0.0.5", "10.0.0.4"
	part := func(first string, size int) string {
		return first + "," + strings.Repeat(" ", size-len(first)-len(proxy)-1) + proxy
	}
	left := part(client, 2048)
	for _, total := range []int{4096, 4097} {
		right := part(proxy, total-len(left)-1)
		fields := []string{left, right}
		if len(left) > 2048 || len(right) > 2048 || len(strings.Join(fields, ",")) != total {
			t.Fatal("invalid aggregate-byte fixture")
		}
		want := client
		if total > 4096 {
			want = peer
		}
		for i, values := range [][]string{fields, {strings.Join(fields, ",")}} {
			t.Run(fmt.Sprintf("bytes%d/form%d", total, i), func(t *testing.T) {
				if got := sourceFromFields(t, peer+":443", values); got != want {
					t.Fatalf("source = %q, want %q", got, want)
				}
			})
		}
	}
}

func TestSourceKeyRepeatedFieldsAggregateHops(t *testing.T) {
	const client, peer, proxy = "192.0.2.9", "10.0.0.5", "10.0.0.4"
	for _, count := range []int{32, 33} {
		individual := make([]string, count)
		individual[0] = client
		for i := 1; i < count; i++ {
			individual[i] = proxy
		}
		two := []string{client, strings.TrimSuffix(strings.Repeat(proxy+",", count-1), ",")}
		want := client
		if count > 32 {
			want = peer
		}
		for layout, fields := range [][]string{individual, two} {
			for form, values := range [][]string{fields, {strings.Join(fields, ",")}} {
				t.Run(fmt.Sprintf("hops%d/layout%d/form%d", count, layout, form), func(t *testing.T) {
					if got := sourceFromFields(t, peer+":443", values); got != want {
						t.Fatalf("source = %q, want %q", got, want)
					}
				})
			}
		}
	}
}
```

- [ ] Run `go test -json -count=1 -run '^TestSourceKeyRepeatedFieldsAggregate' ./internal/security/rate_limit`. Expected RED on4a0 specifically for split4097 and split33, with combined controls and exact4096/32 passing. Count33 is exercised both as33 fields and as33 hops across2 fields; a field-count bound alone is insufficient.

## Task 3: Make the bounded production change and prove GREEN

**Modify:** backend/internal/security/rate_limit/source.go only. Keep the unchanged code around sourceKey; this complete final file defines the intended implementation.

- [ ] Replace source.go with the following equivalent small change. The pre-join field bound is valid because combining N list field values yields at least N comma-separated components, including empty components. The subtraction guard prevents overflow and allocation before rejecting aggregate bytes.

```go
package ratelimit

import (
	"fmt"
	"net"
	"net/http"
	"strings"
)

const maxForwardedHeaderBytes = 4096
const maxForwardedHops = 32

func parseTrustedProxies(values []string) ([]*net.IPNet, error) {
	trusted := make([]*net.IPNet, 0, len(values))
	for _, value := range values {
		_, network, err := net.ParseCIDR(strings.TrimSpace(value))
		if err != nil {
			return nil, fmt.Errorf("invalid trusted proxy CIDR %q: %w", value, ErrInvalidConfig)
		}
		trusted = append(trusted, network)
	}
	return trusted, nil
}

func sourceKey(request *http.Request, trusted []*net.IPNet) string {
	peer := remoteIP(request.RemoteAddr)
	if peer == nil {
		return request.RemoteAddr
	}
	if !isTrusted(peer, trusted) {
		return peer.String()
	}
	fields := request.Header.Values("X-Forwarded-For")
	if len(fields) == 0 || len(fields) > maxForwardedHops {
		return peer.String()
	}
	bytes := len(fields) - 1
	for _, value := range fields {
		if len(value) > maxForwardedHeaderBytes-bytes {
			return peer.String()
		}
		bytes += len(value)
	}
	forwarded := strings.Join(fields, ",")
	if forwarded == "" {
		return peer.String()
	}
	hops := strings.Split(forwarded, ",")
	if len(hops) > maxForwardedHops {
		return peer.String()
	}
	current := peer
	for index := len(hops) - 1; index >= 0 && isTrusted(current, trusted); index-- {
		candidate := net.ParseIP(strings.TrimSpace(hops[index]))
		if candidate == nil {
			return peer.String()
		}
		current = candidate
	}
	return current.String()
}

func remoteIP(remote string) net.IP {
	host, _, err := net.SplitHostPort(remote)
	if err != nil {
		host = strings.Trim(remote, "[]")
	}
	return net.ParseIP(host)
}

func isTrusted(address net.IP, trusted []*net.IPNet) bool {
	for _, network := range trusted {
		if network.Contains(address) {
			return true
		}
	}
	return false
}
```

- [ ] Run `gofmt -w internal/security/rate_limit/source.go internal/security/rate_limit/source_fields_test.go internal/security/rate_limit/source_limits_test.go` from backend.
- [ ] Verify `go version` is go1.26.4; use GOTOOLCHAIN=local and the installed race-capable compiler, with cached dependencies. Run the following from backend, retaining JSON stdout/stderr plus exact argv/platform/source hash. Reject skipped tests/build failures; do not count them as passing variants.

```powershell
$env:GOTOOLCHAIN = 'local'
$native = Join-Path (Split-Path (Get-Location).Path -Parent) '.out/issue138/native-green-attempt1'
if (Test-Path -LiteralPath $native) { throw 'use_a_new_native_attempt_directory' }
New-Item -ItemType Directory -Path $native | Out-Null
$raceLog = Join-Path $native 'rate-limit-race.jsonl'
$configLog = Join-Path $native 'invalid-CIDR.jsonl'
go test -json -p=2 -race -count=3 -timeout=3m ./internal/security/rate_limit *> $raceLog
if ($LASTEXITCODE -ne 0) { throw 'native_rate_limit_failed' }
go test -json -count=1 -run '^TestLoadRejectsInvalidTrustedProxyCIDR$' ./internal/config/runtime *> $configLog
if ($LASTEXITCODE -ne 0) { throw 'invalid_CIDR_preservation_failed' }
$raceEvents = Get-Content -LiteralPath $raceLog | ForEach-Object { $_ | ConvertFrom-Json }
$configEvents = Get-Content -LiteralPath $configLog | ForEach-Object { $_ | ConvertFrom-Json }
if (@(@($raceEvents)+@($configEvents) | Where-Object Action -eq 'skip').Count) { throw 'native_skips_forbidden' }
if (@($raceEvents | Where-Object { $_.Action -eq 'pass' -and $_.Test -and $_.Test -notmatch '/' }).Count -ne 30) { throw 'expected_original18_plus_new12_top_level_PASS_events' }
if (@($configEvents | Where-Object { $_.Action -eq 'pass' -and $_.Test -eq 'TestLoadRejectsInvalidTrustedProxyCIDR' }).Count -ne 1) { throw 'invalid_CIDR_test_not_executed' }
if (Select-String -LiteralPath $raceLog -SimpleMatch 'WARNING: DATA RACE') { throw 'native_race_reported' }
```

- [ ] Expected GREEN: the six unchanged original top-level package tests retain18 PASS events over3 repeats; four new top-level tests add12 PASS events, plus their subtests. Invalid-CIDR remains1 PASS; zero skips/races. Preserve RED outputs separately. Requirements/backlog/OpenAPI do not change, so no contract/spec rewrite or unrelated validators are added.

## Task 4: Qualify a representative first-field regression mutation

- [ ] From the future implementation worktree root run this overlay-only negative control. It changes no checked-out source, retains the mutant/outputs, and deliberately restores the prior Header.Get behavior. The three named retained regressions must fail three times each; compile failure, unrelated test failure or a surviving mutant is not qualified.

```powershell
$repo = (Get-Location).Path
$source = Join-Path $repo 'backend/internal/security/rate_limit/source.go'
$dir = Join-Path $repo '.out/issue138/mutation-first-field-attempt1'
if (Test-Path -LiteralPath $dir) { throw 'use_a_new_attempt_directory' }
New-Item -ItemType Directory -Path $dir | Out-Null
$text = [IO.File]::ReadAllText($source)
$needle = 'fields := request.Header.Values("X-Forwarded-For")'
if ([regex]::Matches($text, [regex]::Escape($needle)).Count -ne 1) { throw 'exact_single_mutation_edge_required' }
$mutant = Join-Path $dir 'source.go'
[IO.File]::WriteAllText($mutant, $text.Replace($needle, 'fields := []string{request.Header.Get("X-Forwarded-For")}'), [Text.UTF8Encoding]::new($false))
$overlay = Join-Path $dir 'overlay.json'
$replace = @{}; $replace[$source] = $mutant
[IO.File]::WriteAllText($overlay, (@{ Replace=$replace } | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
$log = Join-Path $dir 'go-test.jsonl'
Push-Location (Join-Path $repo 'backend')
try {
    go test -json -p=2 -race -count=3 -timeout=3m "-overlay=$overlay" -run '^TestSourceKey(RepeatedFields|OrderedFields)' ./internal/security/rate_limit *> $log
    $exit = $LASTEXITCODE
} finally { Pop-Location }
if ($exit -eq 0) { throw 'first_field_mutant_survived' }
$events = Get-Content -LiteralPath $log | ForEach-Object { $_ | ConvertFrom-Json }
if (@($events | Where-Object Action -eq 'skip').Count) { throw 'mutation_has_skips' }
foreach ($name in @('TestSourceKeyRepeatedFieldsNearestBoundary','TestSourceKeyRepeatedFieldsAggregateBytes','TestSourceKeyRepeatedFieldsAggregateHops')) {
    if (@($events | Where-Object { $_.Action -eq 'fail' -and $_.Test -eq $name }).Count -ne 3) { throw "unqualified_mutation_failure_$name" }
}
if (Select-String -LiteralPath $log -SimpleMatch 'WARNING: DATA RACE') { throw 'mutation_has_race' }
```

- [ ] Inspect git status/diff and line counts. Source should stay below100 and each test file below100; hard120 applies. Only the three named files belong in the future implementation commit. After native GREEN and qualified mutation, stage those exact files and commit `fix: bound ordered forwarded fields`; do not stage this Android QA worktree, generated Flutter files, .out or secrets. This is a future execution step, not authorization to commit during this plan-only packet.

## Task 5: Root-owned actual API/Caddy and literal-wire acceptance gate

The upcoming separate harness-adaptation packet owns executable QA-controller changes and exact launch commands. It must use a fresh isolated fixture and unique output, not run the old scripts or overwrite e2dac artifacts. Root controls all requests; no product/config/policy changes are introduced by the probes. Current fresh source4a0 can serve as RED baseline; final candidate must be rebuilt/source-bound and use independent fresh budget identities without resets/spoofed immediate peers.

- [ ] Attest final Git SHA/tree/archive, actual API image/source, Go1.26.4/PostgreSQL17.6, mounted and active standard Caddy config, unchanged source10/300s/cap policy and trusted P/32. Keep API/admin unpublished; retain real two distinct untrusted TCP peer namespaces A/B. Audit runtime trust/topology before interpreting status. Addresses/config/raw bodies remain private; no account/session/attachment provisioning is necessary.
- [ ] Reproduce the full historical100-case normal-HTTP encoder matrix, adapted only for the fresh fixture and expected GREEN. Preserve untrusted A direct spoof/missing/repeated/X-Real-IP/Forwarded controls; Caddy exhausted A stays429; independent B receives ten malformed-body400 admissions then429 and shares the exhausted key with direct B. Preserve trusted IPv4/mapped/IPv6-normalized budgets, nearest-untrusted stopping, changed ignored-left values and all malformed/empty controls. Do not infer trusted-boundary success from Caddy sanitization alone.
- [ ] Require repeated ordered boundary and same-order combined controls to share the exhausted B key: P sends `[A]`, then `[B,P]` as two XFF lines; both separated and combined forms return429 with positive Retry-After after B's ten400 admissions. Changing ignored-left A cannot obtain a fresh budget. Reverse/order-sensitive controls use the actual intended nearest boundary.
- [ ] Add the retained exact-edge cases to the full matrix: two individually-small fields combining to4096 (accepted) and4097 (peer fallback, including separator byte); exactly32 versus33 total hops, split into2 fields and into32/33 fields; same-order combined controls. Byte padding must remain internal to each field like Task2, so native HTTP outer-whitespace trimming cannot erase the intended size or confound separated/combined comparison. Keep empty-leading/trailing and malformed-left/inside-trusted-walk semantics aligned with native tests. Upper-bound/malformed fallback is demonstrated using an already exhausted immediate P budget, not merely a400 from an arbitrary fresh key.
- [ ] Run an independent literal TCP HTTP1 CRLF writer from the actual trusted P namespace, not the normal encoder. Replay all18 historical wire cases with GREEN expectations (the historical three separate-line400 mismatches become429) and add aggregate/exact-edge split-versus-combined pairs. Save private byte digest and field-line count so a client library's combination cannot fake repeated lines. Reject partial reads/controller parse failures and record actual response code/Retry-After.
- [ ] Require malformed one-byte login bodies to stop before credential parsing/account/KDF work:400 means admitted source budget,429 RATE_LIMITED means exhausted source budget. Match API aggregate counters to actual requests, and require KDF/account-admission/store-saturation deltas0. No credential/KDF authentication or ACL bypass claim follows from these statuses.
- [ ] Verify unchanged DB counts (users/sessions/attachments), unchanged retained services/config, no restart/reset used to reset budgets, exact owned helper cleanup and post-run health. Preserve every failed controller/fixture attempt; no standard-Caddy public bypass or physical multi-proxy/media/platform claim. New independent evidence must say all executed matrix cases PASS with exact counts, source/config/runner/output hashes, timing bounds and no skips.
- [ ] Root/release review the actual final-source evidence before issue138 closure. Native GREEN or the old0724 witness alone cannot close the runtime gate. No user permission question is pending: implementation and later bounded QA are already delegated; root dispatches their execution.

## Edge decision and self-review

No unresolved owner question. Combining parsed field values in their received order with a comma (without adding a space) is the selected canonical rule. Therefore an empty first field followed by an untrusted client resolves like `,client` and ignores the empty left component after reaching that boundary; an empty trailing component or malformed component still inside the trusted walk falls back to the peer. Bounds count parsed Header.Values bytes exactly as joined, not raw field-name/CRLF/outer-whitespace bytes, and count all hops including empty components even left of the eventual boundary. Internal padding in Task2 survives real HTTP parsing; outer-whitespace-only padding would be an invalid aggregate-limit wire witness. Noncanonical manually constructed http.Header map keys are not a new feature; real net/http parsing canonicalizes field names and prior Get had the same lookup convention.

Coverage: all five original138 acceptance rows map to Task1/2 native preservation plus Task5 real untrusted/Caddy/trust/config evidence. The three historical RED triggers are explicit retained tests; exact4096/32 edges, split-versus-combined, IPv4/6, empty/malformed and untrusted early return are pinned. A representative mutation must fail semantic tests. One production file/two tests stay within ratchets; no trust/cap/window/config contract changes. This packet is PLAN_ONLY: no product source, test execution, network, infrastructure, staging, commit or #134 artifact change.

Slavik Gym report: route=backend/security/rate_limit/source; packet=review_gate-plan; tokens=estimated:7800; method=manual_estimate; driver=exact4a0-source-and-immutable-counterexample; next_split=delegated-implementation-then-root-runtime-gate.

## Implementation binding (authorized inline execution)

Actual base=d7cc1d381fffebf6ec095b1e9486b41bc145c3b2; whole tree equals approved4a0 baseline. Branch=codex/fix-forwarded-fields-138 in separate managed forwarded-fields-138 worktree. Approved original planSHA78e4d326840e800451bf714599504a45f9b9c35aae2348e9e29ec7352edd6088 remains untouched in root A. Execute inline as already delegated; no execution-choice question. Production source remains source.go only, with the exact approved bounded Header.Values change. Add a bounded source_wire_test.go for actual HTTP1 repeated field lines before the fix. Use Linux Go1.26.4/CGO1 -race, not unsupported Windows default-CGO race. Expected total top-level PASS events becomes33 over count3 (18 preserved +12 planned +3 actual-wire); all skips forbidden. Root owns isolated API/Caddy matrices, source switch and final cleanup/acceptance; no merge/closure until that verdict.

## Bounded actual HTTP1 retained regression

Create backend/internal/security/rate_limit/source_wire_test.go before the product edit (executed RED: separate field lines FAIL, combined control PASS). Exact executed code:

```go
package ratelimit

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestSourceKeyLiteralHTTP1RetainsOrderedFields(t *testing.T) {
	trusted, err := parseTrustedProxies([]string{"127.0.0.1/32", "10.0.0.0/8"})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprintf(writer, "%s|%d", sourceKey(request, trusted), len(request.Header.Values("X-Forwarded-For")))
	}))
	defer server.Close()
	cases := []struct{ name, headers, want string }{
		{"separate", "X-Forwarded-For: 203.0.113.9\r\nX-Forwarded-For: 192.0.2.9,10.0.0.4\r\n", "192.0.2.9|2"},
		{"combined", "X-Forwarded-For: 203.0.113.9,192.0.2.9,10.0.0.4\r\n", "192.0.2.9|1"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			connection, err := net.DialTimeout("tcp", strings.TrimPrefix(server.URL, "http://"), time.Second)
			if err != nil {
				t.Fatal(err)
			}
			defer connection.Close()
			if err := connection.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
				t.Fatal(err)
			}
			_, err = fmt.Fprintf(connection, "GET / HTTP/1.1\r\nHost: qa.invalid\r\nConnection: close\r\n%s\r\n", tc.headers)
			if err != nil {
				t.Fatal(err)
			}
			response, err := http.ReadResponse(bufio.NewReader(connection), &http.Request{Method: http.MethodGet})
			if err != nil {
				t.Fatal(err)
			}
			defer response.Body.Close()
			body, err := io.ReadAll(response.Body)
			if err != nil || response.StatusCode != http.StatusOK || string(body) != tc.want {
				t.Fatalf("literal HTTP1 source/count = %q, status %d, error %v; want %q", body, response.StatusCode, err, tc.want)
			}
		})
	}
}
```

Execution checkpoint: original18 PASS; exact newtests RED14 fail/19 pass events with unchanged source; Windows and pinnedLinuxCGO1-race GREEN117 PASS events/33 top-level over count3,0skip; config11 PASS events including invalidCIDR/default10-300; Header.Get overlay mutation42 semanticFAIL/57PASS,0skip and fixedbytes unchanged; fullLinux vet/build and nativecontracts PASS. Root runtime/fullhostedCI/merge/closure remain pending.
