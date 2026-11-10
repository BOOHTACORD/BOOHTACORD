# Issue 689: order roster resource changes with delivery

- RED: the session-only guard does not lock participant sessions, leases,
  accounts or channels. A revoke after the earlier roster check can race write.
- Leaf: PostgreSQL delivery authorization. Acquire bounded shared locks for the
  relevant rows, repeat the visibility/lease comparison in the same transaction,
  and hold them through the context-bounded socket write. Test both ordering
  directions for lease revoke, participant session revoke, ban and archive.
- Preserve existing shared coordinator, bounded worker limits and unavailable
  behavior. Never hold event-hub or coordinator mutexes through database I/O.
- Stop: real database races, unchanged baseline behavior, slow-client pool and
  load measurements pass. Role/ACL policy and phantom topology cases must not be
  claimed until independently tested; release is not authorized by this packet.
