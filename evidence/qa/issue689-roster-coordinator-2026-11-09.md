# Issue 689: isolated roster coordinator

- PASS: 20 native Go runs, five Linux race runs, Go vet and spec traceability. Tests cover per-account isolation, fresh initial barrier, stale read rejection, invalidation, unchanged suppression, unavailable/recovery, subscriber closure, cancellation, bounded workers/admission and replaceable slow-subscriber delivery.
- PASS: an isolated test with 100 subscriptions to one account coalesced concurrent initialization into one fresh shared read after discarding the superseded read. This is not a hardware or application capacity claim.
- A churn test first exposed blocking under a full queue; admission is now nonblocking and waiting work is rescheduled. An orphaned read test first exposed a missing cancellation; the last subscriber now cancels its in-flight work.
- NOT RUN: runtime registration, actual DB/LiveKit/webhook integration, per-recipient session and ACL/lease validation immediately before writes, socket backpressure and the required load matrix. No roster is emitted by this packet.
