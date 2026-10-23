# Password reset capability preflight (SEC-003 / #535)

The reset endpoint preserves its external IP limit (5 / 15 minutes), Origin/CSRF,
strict request fields, 8 KiB body limit, password policy and public response shape.
It accepts a reset capability, never a client-selected account identifier.

The service observes request cancellation, validates token encoding and password,
then calls `Store.Preflight(ctx, digest)`. PostgreSQL binds only the SHA-256 digest
in an indexed `SELECT 1` against the existing primary key. Missing, used or expired
capabilities return the same `ErrInvalidOrExpired` / HTTP 400 as before, without
Argon2 or Consume. It returns no account ID, account state or expiry to clients.

Preflight has a query deadline of at most two seconds (an earlier request deadline
wins). Connection-pool wait and query execution use that context. A query error or
timeout fails closed as infrastructure failure: it cannot authorize KDF/reset or
become a missing-token verdict. The HTTP layer retains its generic safe 500.

The production pool executes the SELECT in autocommit mode. There is no row lock,
`FOR UPDATE`, explicit transaction or token consumption during preflight, and no
transaction spans expensive password hashing. The result is advisory, not a
reservation or authorization for an unconditional password UPDATE.

After preflight the service checks cancellation again and calls the unchanged
shared KDF admission: four active slots, zero waiting queue, native Go Argon2id
with unchanged parameters. Busy valid requests return existing 503 AUTH_BUSY /
Retry-After: 1; invalid capabilities are rejected before that resource gate.
There is no per-token map, singleflight cache, second semaphore or secret queue.
Several valid preflights can hash concurrently within the existing global bound.

After Hash returns the service checks context once more before invoking Consume.
The original atomic PostgreSQL CTE remains unchanged: it rechecks `used_at IS NULL`
and `expires_at > now()`, marks use, changes password, revokes sessions and voice
leases, enqueues SFU revocations and records audit in one operation. A concurrent
winner or intervening expiry can therefore reject a previously valid preflight.
Any final SQL error rolls back the whole statement. Preflight itself does not
hold the token against a concurrent request.

A successful reset invalidates the old password and sessions, and the replacement
hash remains compatible with the normal verifier. Enqueued revocation is not
proof of a physically disconnected SFU participant; existing media gates retain
that responsibility. An ambiguous connection/commit/response error does not
prove the password remained unchanged: a server operation may have committed.
Clients must not automatically replay password mutations. The next attempt can
legitimately find a used token.

Web and shared Flutter retain their existing generic unavailable-link message on
400, safe infrastructure feedback on 500, manual retry feedback on AUTH_BUSY and
success result. No response exposes token/account details, no password or raw
capability enters metrics/logs, and no extra persistent credential storage or
client logout is introduced. An unavailable-link result still asks the user for a
new administrator-issued link, rather than disclosing why this one failed.

Evidence: `evidence/security/sec03-reset-preflight-2026-10-23.md`. Source/API tests
and owned PostgreSQL prove the ordering/atomicity claims; they are not a
production capacity, physical-device or media-removal certification.
