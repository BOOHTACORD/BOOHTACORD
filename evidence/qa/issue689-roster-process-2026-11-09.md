# Issue 689: shared roster process lifecycle

- PASS: focused tests show notifier hints cause a shared coordinator read, stopping closes the active stream and prevents new admission; ten Go repetitions, ten Linux race-detector repetitions, Go vet and spec traceability passed.
- NOT RUN: signed webhook through the real HTTP stack, application route wiring, concurrent revocation at socket write, final client acceptance and load. The test notifier is an injected hint source, not proof of webhook signature verification.
