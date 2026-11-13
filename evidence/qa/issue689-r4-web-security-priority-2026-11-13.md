# Issue #689 R4: Web security priority, partial

- In the coalesced Web workspace delivery path, an indefinitely blocked message
  batch delayed session and permission events. A focused test reproduced the
  delay with 256 outstanding synthetic hints.
- That path starts session and permission work ahead of the message batch;
  permission hints are sequenced so a later hint does not share an earlier
  permission request solely because both were delivered concurrently. A failed
  security handler triggers recovery, and queued work from an old delivery
  generation is not started after disconnect. Voice revocation stays independent.
- Ninety-three Web realtime/maintenance tests, typecheck, client parity and
  the signal inventory check passed. Tests use synthetic local handlers.
- An already-running unrelated permission refresh can still be coalesced by the
  permission store; its stale-response behavior needs a separate fix and test.
  The non-coalesced Web path, Flutter priority, real slow readers, end-to-end
  authorization under pressure, native platforms and production remain NOT_RUN.
