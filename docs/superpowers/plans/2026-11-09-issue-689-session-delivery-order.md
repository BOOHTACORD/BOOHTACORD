# Issue 689: order session revocation and roster writes

- The focused socket test demonstrates a revoke between final authorization and
  frame write. This packet addresses only session/account revocation ordering.
- Use a bounded PostgreSQL transaction with shared locks on the current session
  and account, revalidate immediately inside that transaction, and bound the
  callback and pool slots. A committed revocation must precede a rejected write
  or follow the completed write; do not hold the event-hub lock across I/O.
- First test real PostgreSQL contention in both orders. Then integrate the guard
  at the actual roster writer and retain failure on unavailable dependencies.
- ACL, voice-lease, channel and natural-expiry races, deadlocks, pool pressure,
  slow clients and full security/load matrices remain separate open work. No
  production acceptance follows from the session-only result.
