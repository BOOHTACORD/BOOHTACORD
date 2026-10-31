# Upload socket read deadline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Interrupt real blocked HTTP/1 upload reads and release resources at the existing idle/absolute policies for TEXT and DM.

**Architecture:** Bind each admitted upload to its actual ResponseWriter using ResponseController. Check native deadline support at entry. Managed timers choose min(last progress + idle, absolute end), fix the policy actor/cause before setting a past socket deadline, and unblock only route-local reads. Serialize all controller calls and completion so no late watcher/timer affects a reused connection.

**Tech Stack:** Go1.26.4 net/http, existing storage upload_request, Prometheus/ACL/admission unchanged, PostgreSQL17.6 runtime validation.

---

Operating brief: workflow_class=small_direct; task_size=medium; structure_mode=structure_no_rg. Leaf=storage/upload_request/read_deadline; backlog T-044 (T-040/T-041 dependencies). Base=2b95ddd864da210d6fc2f050e69ce2d5d203186e. Scope=the selected leaf, its two exact HTTP callers, typed tests and evidence only. Source file hard120/production hard16; keep policy idle60s/absolute900s/per-account2/global16, size/ACL/security/metrics/Caddy unchanged. No global TimeoutHandler. Stop condition=focused native/race/policy checks, final exact-head CI including PostgreSQL/Android/macOS and independent real-duration runtime; GitHub closure only after actual criteria PASS.

The optional referenced execution/worktree subskills are not installed (both standard skill roots checked). Owner explicitly selected this inline implementation/release task; use the managed isolated worktree and project-local method without an approval pause.

### Task1: Preserve baseline and execute real socket RED

Files: backend/internal/storage/upload_request/socket_test.go and socket_helpers_test.go (new); existing body.go remains byte-identical to base during RED.

- [x] Record full issue134 and base SHA. Existing two upload_request and two admit_upload tests pass, zero skips, proving the synthetic closer gap remains.
- [x] Run `cd backend; go test ./internal/storage/upload_request -run TestSocketDeadlineUnblocksRealHTTP1Body -count=1 -v` with original three-argument WithLimits call in helper. Four subtests must FAIL by client600ms bound against40ms idle/absolute policies; client/socket cleanup always runs.
- [x] Preserve RED log, original test/helper GitLF hashes and original production hash before any implementation edit. Raw test bodies are owned constant bytes, no credentials.

### Task2: Bind route-local deadlines and preserve completion ordering

Files: modify upload_request/body.go; create upload_request/read_deadline.go and lifecycle.go; modify upload_text_attachment/api/http_handler.go and upload_direct_message_attachment/api/http_handler.go. Extract existing TEXT writeError byte-for-byte to api/http_response.go only if needed to keep changed files<=120 lines.

- [x] Implement these complete source units after the socket RED; then gofmt.

`backend/internal/storage/upload_request/body.go`

```go
package uploadrequest

import (
	"context"
	"errors"
	"io"
	"sync"
	"sync/atomic"
	"time"
)

var ErrReadTimeout = errors.New("upload body read deadline exceeded")

type timeoutKey struct{}

func TimedOut(ctx context.Context) bool {
	state, _ := ctx.Value(timeoutKey{}).(*atomic.Bool)
	return state != nil && state.Load() || errors.Is(context.Cause(ctx), ErrReadTimeout)
}

type boundedBody struct {
	source      io.ReadCloser
	ctx         context.Context
	cancel      context.CancelCauseFunc
	mutex       sync.Mutex
	timer       *time.Timer
	idle        time.Duration
	deadline    *readDeadline
	expired     atomic.Bool
	finished    bool
	interrupted bool
}

func (body *boundedBody) Read(buffer []byte) (int, error) {
	if cause := context.Cause(body.ctx); cause != nil {
		return 0, cause
	}
	count, err := body.source.Read(buffer)
	body.mutex.Lock()
	defer body.mutex.Unlock()
	if body.expired.Load() {
		return count, ErrReadTimeout
	}
	if cause := context.Cause(body.ctx); cause != nil {
		return count, cause
	}
	if count > 0 && !body.finished {
		body.deadline.advance()
		body.timer.Reset(body.idle)
	}
	return count, err
}

func (body *boundedBody) Close() error {
	err := body.source.Close()
	body.timer.Stop()
	return err
}
```

`backend/internal/storage/upload_request/read_deadline.go`

```go
package uploadrequest

import (
	"net/http"
	"time"
)

type readDeadline struct {
	controller  *http.ResponseController
	maximum, at time.Time
	idle        time.Duration
}

func newReadDeadline(writer http.ResponseWriter, maximum, idle time.Duration) (*readDeadline, error) {
	deadline := &readDeadline{controller: http.NewResponseController(writer), maximum: time.Now().Add(maximum), idle: idle}
	deadline.advance()
	// Check native support before reading. The timer owns expiry classification;
	// a parallel future socket expiry could cancel the parent context first.
	return deadline, deadline.controller.SetReadDeadline(time.Time{})
}

func (deadline *readDeadline) advance() {
	deadline.at = time.Now().Add(deadline.idle)
	if deadline.maximum.Before(deadline.at) {
		deadline.at = deadline.maximum
	}
}

func (deadline *readDeadline) interrupt() { _ = deadline.controller.SetReadDeadline(time.Now()) }
func (deadline *readDeadline) clear()     { _ = deadline.controller.SetReadDeadline(time.Time{}) }
```

`backend/internal/storage/upload_request/lifecycle.go`

```go
package uploadrequest

import (
	"context"
	"errors"
	"net/http"
	"time"
)

func WithLimits(writer http.ResponseWriter, request *http.Request, maximum, idle time.Duration) (*http.Request, func(), error) {
	deadline, err := newReadDeadline(writer, maximum, idle)
	if err != nil {
		return request, func() {}, err
	}
	ctx, cancel := context.WithCancelCause(request.Context())
	body := &boundedBody{source: request.Body, ctx: ctx, cancel: cancel, idle: idle, deadline: deadline}
	ctx = context.WithValue(ctx, timeoutKey{}, &body.expired)
	body.ctx = ctx
	body.timer = time.AfterFunc(idle, func() { body.interrupt(ErrReadTimeout) })
	maximumTimer := time.AfterFunc(maximum, func() { body.interrupt(ErrReadTimeout) })
	stopCancel := context.AfterFunc(request.Context(), func() { body.interrupt(context.Cause(request.Context())) })
	request.Body = body
	return request.WithContext(ctx), func() {
		body.mutex.Lock()
		body.finished = true
		maximumTimer.Stop()
		body.timer.Stop()
		stopCancel()
		body.deadline.clear()
		body.mutex.Unlock()
		cancel(nil)
	}, nil
}

func (body *boundedBody) interrupt(cause error) {
	body.mutex.Lock()
	if body.finished || body.interrupted {
		body.mutex.Unlock()
		return
	}
	if errors.Is(cause, ErrReadTimeout) && time.Now().Before(body.deadline.at) {
		body.mutex.Unlock()
		return
	}
	body.interrupted = true
	body.expired.Store(errors.Is(cause, ErrReadTimeout))
	body.cancel(cause)
	body.deadline.interrupt()
	body.mutex.Unlock()
	_ = body.source.Close()
}
```

- [x] Both exact handlers replace their old WithLimits assignment with this binding; existing timeout/error/ACL/body-size paths remain intact:

```go
request, cleanup, err := uploadrequest.WithLimits(writer, request, uploadMaximumDuration, uploadIdleDuration)
if err != nil {
 failures.UploadFailed("internal")
 writer.Header().Set("Connection", "close")
 writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить вложение")
 return
}
defer cleanup()
defer request.Body.Close()
```

- [x] Adapt the two existing synthetic unit tests and socket helper to the new actual writer/error result; keep every socket assertion and policy bound unchanged. Synthetic writers explicitly implement SetReadDeadline and never stand in for real socket proof.
- [x] Add native tests for ErrNotSupported/error writer fail-closed before source read/uploader, real HTTP1 cancellation, allowed progress, maximum despite progress, and successful upload→delayed non-upload request on the same keep-alive socket.
- [x] Real keep-alive follow-up body remains readable beyond the previous idle deadline after the old handler context cancellation. A deterministic controlled native-writer test proves timeout/cause are fixed before native read cancellation. Unrelated OS/network/read failures remain negative controls; a stale idle callback cannot expire a new progress window.
- [x] Run focused tests and race checks: `go test -race ./internal/storage/upload_request ./internal/storage/admit_upload ./internal/storage/upload_text_attachment/api ./internal/storage/upload_direct_message_attachment/api -count=1`.
- [x] Retain a mutation control disabling socket interrupt on the final test source (or the original implementation adapted only for the new signature): socket cases must fail, then restore fixed bytes exactly. Do not call compilation/API mismatch a RED.

### Task3: Publish a reviewable exact source candidate

Files: this plan and evidence/qa/issue134-upload-read-deadline-2026-10-31.json.

- [ ] Inspect every changed path/size and gofmt/diff checks. Record source/test fingerprints, baseline/RED/GREEN/mutation commands and log hashes, preserved policies, mandatory trigger/platform/results and honest runtime PENDING.
- [ ] Commit explicit paths on codex/fix-upload-read-deadline-134. Send root/local_qa_deploy exact immutable source SHA before CI/merge for independent runtime.
- [ ] Push and create PR using Refs #134, without automatic closing syntax. Full CI must actually pass PostgreSQL17.6, Android and macOS; preserve failures without weakening gates.
- [ ] Root owns isolated Caddy/Go/PostgreSQL runtime: TEXT+DM zero/partial idle60s, true900s with progress, disconnect/cancel, ENOSPC, account2/global16, progress/retry/cleanup zero, voice/realtime long-lived policy. No production fault/load.
- [ ] Merge/release only through existing approved delivery workflows; preserve exact-source bundle/readback provenance. Close issue134 only after all its original implementation/acceptance checkboxes are actually supported by root runtime and final CI/release evidence. Other QA gates stay separate.


### Recorded design refinements

The first future-native-deadline prototype and its classification race failures are retained, not accepted. Final code uses one timer-owned policy actor, capability check before reading, a past native deadline only for actual interruption, and a request-local atomic classification marker. The first cancellation/timeout actor wins under the body mutex; stale idle callbacks return without mutating fresh progress. Final Windows native and pinned Go1.26.4 Linux race tests pass. Full backend static dependency setup, hosted PostgreSQL/Android/macOS CI and real TLS/Caddy durations remain separate pending gates.

### Task4: Qualified proxy delivery follow-up

Source718 remains the immutable backend/native prior scope. Root confirmed direct real-route408 at60.02s but default keep-alive TLS/Caddy0bytes at80s; explicit CLIENT Connection:close is a diagnostic control, not the production fix.

- [x] Add tools/qa/upload_proxy/run.py and six typed Go overlay test/helper files. Require the actual pinned Caddy2.10.0 binary/SHA; no skip or fake proxy. Run the existing production Caddyfile unchanged and retain native RED.
- [x] Add only a POST/exact TEXT-DM path/HTTP1.x request match and upstream408 response handler setting frontend Connection:close before copy_response in deploy/caddy/Caddyfile. No global duplex/timeouts, no valid-upload closing or cap changes.
- [x] Run native Caddy GREEN, retain config/binary/test/log fingerprints and scope/progress/keep-alive controls, then compare source-before-fix again as a qualified mutation.
- [ ] Freeze and hand off a new exact immutable source before any MAIN reload. Root reruns all real TLS duration/cleanup/concurrency/ENOSPC/realtime criteria; full CI repeats on the final new head.

### Task5: Required native proxy regression discovery

Root approved this validation-only integration after ce7. Do not change backend, deploy, clients/web or tools/toolchains.json. Runtime remains actual APIce7/Caddyce7/Web2b95; prove those whole trees equal the final validation head without relabelling actual runtime or repeating15minutes for CI-only changes.

- [x] Add an unconditional `python -m tools.qa.upload_proxy.ci` step after Compose validation in existing required contracts job; always retain source/run/attempt native receipts and logs, including failures.
- [x] Pin the approved Caddy2.10.0 image manifest, Linux binary SHA and embedded Go1.24.2. Extract only from a unique stopped/labelled/no-network container, fail closed on identity/hash/state mismatch, and remove only that validated container without force or image pruning.
- [x] Reject absent/partial/skipped native suites and cleanup failure; keep the actual12-case native fixture unchanged. Run focused wrapper/discovery/Actions/trust/toolchain tests before committing.
- [x] Document protects -> command -> platform -> mandatory trigger -> result location in tools/qa/upload_proxy/README.md. Local mocked extraction checks and actual hosted execution remain separately labelled.
- [ ] Commit explicit validation paths and send immutable head plus backend/deploy/Web/toolchain tree equality to root. Repeat full CI including PostgreSQL17.6/Android/macOS and the new actual native Caddy step; verify retained artifact source/counts/cleanup. Merge and issue closure still await root complete runtime PASS.
