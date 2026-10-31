# Attachment upload deadlines

TEXT and DM attachment routes retain an idle read budget of60seconds and an
absolute budget of900seconds. Successful body reads refresh only the idle
deadline; they never extend the absolute end. Per-account2/global16 concurrent
admission,25MB file-size/disk reservation, server ACL and cookie/CSRF policy are
unchanged. Disk reservation is not a25MB RAM allocation.

The upload handler binds its actual HTTP ResponseWriter to ResponseController.
Managed timers choose the earlier of idle and absolute expiry. The policy actor
fixes UPLOAD_TIMEOUT/408 before setting a past socket deadline to unblock the
read; a parallel future native expiry cannot cancel the parent first. Parent
cancellation is a separate first actor. An unrelated reader failure is not a
policy timeout.
Unsupported deadline control fails closed before parsing/staging, with INTERNAL
and Connection:close. Actual middleware wrappers must retain Unwrap support.

Completion stops timers/watchers, marks the request finished and clears its
read deadline while the handler still owns the writer. A queued callback cannot
alter the next keep-alive request. No global TimeoutHandler, server-wide upload
ReadTimeout, write deadline or WebSocket lifetime limit is installed.

The existing Caddy reverse proxy and its separate realtime/media routes remain
unchanged. The API owns these upload budgets. Mandatory release verification
must use normal TLS through Caddy and observe the actual408/code on the client
with its frontend body still unfinished; backend resource release alone does
not prove that the proxy delivered the response. Test direct API separately if
proxy behavior differs, retain both results and diagnose a bounded proxy fix.

For both routes, run headers-only/partial multipart idle60s, true900s absolute
with continuing progress, disconnect/cancel, isolated ENOSPC, account/global
overflow, valid slow progress and a successful retry after timeout. Require
inflight/reservation/staging counters to return to baseline and long-lived
voice/realtime to survive. Observe aggregate uploads_inflight/oldest age and
storage reservation metrics without account, filename or cookie labels.
Do not run fault/load or fill a persistent volume on production.

Short native socket tests exercise ordering and cleanup; they do not replace
real60s/900s TLS/proxy acceptance. See the source-bound issue134 evidence for
actual PASS/FAIL/PENDING results. Existing failures remain historical evidence.
