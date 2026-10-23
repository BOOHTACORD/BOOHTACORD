# Login account admission (SEC-001 / #533)

`POST /api/v1/auth/login` preserves maintenance, same-origin/CSRF, trusted proxy
handling and the source limit (10 attempts / 5 minutes / IP). After strict JSON
parsing under the existing 8 KiB body limit, the handler normalizes the login with
`registration.NormalizeLogin`, then atomically reserves account work **before**
account lookup and the existing shared Argon2 admission. Malformed logins retain
the generic negative auth response and do not perform account lookup.

## Short-window policy and availability

Each process allows 8 reservations per normalized login in a fixed 30-second
window starting with the first reservation. All attempts, including successful
ones and wrong/blocked/unknown-account outcomes, count. A denial does not check a
password, create a session, disclose account existence or extend the deadline.
Correct credentials cannot bypass a denied reservation. The same normalization
and admission policy applies to existing and nonexistent accounts and all IPs.

This deliberately replaces the old post-verifier 8-failures/5-minute policy.
Thirty seconds bounds the normal account-level wait rather than imposing a
five-minute attacker-triggered lock; there is no persistent banned/locked flag,
no requirement for MFA, and no change to administrator-issued password recovery.
Source throttling and shared KDF limits continue to apply independently. Different
accounts behind one NAT have independent account budgets but still share the
existing IP budget. Rejected traffic cannot lengthen the account window; a
sustained distributed attacker can still contest newly available attempts, and
this policy does not promise uninterrupted legitimate access under attack.

Reservations remain live until the synchronous Login call returns. Expired
in-flight entries cannot be replaced while work continues; they retry after an
advisory one second and are removed on completion. A stalled dependency can thus
hold admission longer than 30 seconds; existing request/DB deadlines and process
health must be monitored. There is no detached verifier, waiting request queue,
second semaphore or change to Argon2 parameters.

## Reserve / complete / cancel

Reserve atomically charges one slot and increments in-flight work. Complete is
idempotent and releases running bookkeeping exactly once; it does not normally
refund a slot. Success, invalid credentials, verified blocked accounts,
infrastructure errors and client cancellation after Login starts retain the
charge until the original short window expires. Ambiguous failures cannot be
used as a disconnect/refund bypass. A context rejected before Login starts, or
the shared password gate's typed `ErrBusy` (proven no KDF), refunds exactly once.
No result bookkeeping is keyed by password or client-supplied account ID.

## Bounded storage and scope

At most 50,000 account entries are held in the process. Keys are SHA-256 of the
normalized login, used only in memory; they are not telemetry identifiers and
are never logged. A min-heap expires entries with bounded pruning per reserve.
Active windows and running reservations are never evicted to make room for new
keys. New keys fail closed with the same `429 RATE_LIMITED`; existing entries
retain their budgets. Expired running entries are reclaimed when work finishes.
Heap entries are cleared when popped and are not multiplied on every attempt.

Restarting the API clears these transient budgets. Each replica has its own
budget; this is **not** a deployment-wide distributed throttle. Do not sum it
into a claim about production capacity or add Redis as a default dependency.

## Client and operational contract

The account denial returns `429 RATE_LIMITED`, whole-second `Retry-After`
(rounded up, at least one) and `Cache-Control: no-store`, without a cookie or
credential verdict. Capacity saturation uses the same public contract; retry is
advisory and may still be denied. IP retry may be as long as the existing
five-minute source window. Web and shared Flutter authentication keep masked,
editable inputs and the existing session, show the manual delay, and perform no
automatic password retry or persistent password storage. A user must retry after
the delay; receiving Retry-After is not a scheduled request.

Private Prometheus collectors expose only aggregate active budgets, capacity,
running reservations, admission duration and finite decision/outcome counters:
`voice_platform_login_{budgets_active,budgets_capacity,reservations_active,
admission_total,completion_total,admission_seconds}`. No login/hash/account/IP,
request/session ID, credential or token labels. The former
`rate_limit_sources_*{operation="login_account_failure"}` no longer describes
this policy; network limiter operation series remain unchanged. These metrics
are process-local and are not automatically exported over OTLP. Source catalog
coverage is not proof of storage, alerting or deployed capacity; see #513.
