# Issue 689: disposable load fixture smoke

- PASS: existing `normal` profile with one synthetic account, one logical voice room and a 10-second budget on the local Linux Docker/WSL fixture. The driver recorded 354 requests, no reported operation errors, and clean removal of owned resources.
- FAIL then resolved: an earlier fixture attempt stopped during provisioning because the task-local Windows Git shim did not translate the Linux `git -C` path. That attempt cleaned up its owned resources and is not counted as a pass.
- The API binary SHA-256 was `711a1f918c61a98e3c2070d3df2f4601da2b2ce73f40ee8957a59da6f6dd370c`. The fixture report identifies HEAD `72928320db20baa1ca7c9810d5a7bafe7e8a7533`, but the source worktree also had uncommitted changes; this is not an immutable source identity or a release candidate.
- This existing profile does not opt into the new roster events and does not exercise real media. It is only a fixture smoke. The comparative user/room matrix, 100 guests, NAT, reconnect storm, fault/security scenarios and production capacity remain NOT_RUN. The untracked detailed report is under `.out/backend-load/normal/`.
- PASS (tool smoke only): the new guarded driver completed one account / zero voice rooms against both the clean issue baseline `10e0e44f28a2612d2f7fecf5be06931cf91fb166` and the candidate worktree, with ready, maintenance and roster observations present and owned resources removed. Reports are in `.out/roster-matrix/baseline-1-0-20261109T015104Z-5c12a382/` and `.out/roster-matrix/candidate-1-0-20261109T014925Z-aa52b762/`. Both are `SMOKE_PASS`: the driver was uncommitted, the candidate source was dirty, Flutter tests ran concurrently, and one sample cannot establish p95 or comparative performance. These runs do not close any load gate.
- PASS (instrumentation smoke only): `.out/roster-matrix/candidate-1-0-20261109T021037Z-2406f7fa/` recorded the authenticated scope rising from zero to one while public stayed zero, with owned resources removed. The worktree remained dirty and the full Flutter test was concurrent; public connection counting is covered by a focused socket test but has not yet been demonstrated by this load scenario.
- PASS (public tool smoke only): `.out/roster-matrix/candidate-public-100-20261109T023023Z-42c1dc5b/` held 100 anonymous connections from one loopback source, observed 100 ready and 100 initial maintenance events, saw the public active gauge reach 100, and removed owned resources. Source/driver were dirty and a Windows build ran concurrently. This does not establish p95, a before/after comparison, real users, guest command resistance or full privacy/security acceptance.
- SMOKE_PASS on both source variants with 100 synthetic authenticated accounts and 20 empty rooms: `.out/roster-matrix/baseline-100-20-20261109T025934Z-170fe622/` and `.out/roster-matrix/candidate-100-20-20261109T025816Z-36a61c3d/`. All clients received initial ready, maintenance and roster events; both fixtures removed owned resources. Each used a dirty driver, and candidate source was dirty; screenshots and real media were not part of this test. A Flutter analyzer was concurrent with the candidate run.
- INVESTIGATE: initial maintenance p95 in that single candidate smoke was 51.9 ms versus 9.0 ms in baseline, using the driver's initial-event measurement. These observations are insufficient to attribute a regression or pass the performance gate. Repeat on immutable sources with equivalent conditions and measure actual change propagation, alongside the rest of the required matrix.
- PASS (local instrumentation smoke only): `.out/roster-matrix/candidate-1-0-20261109T031014Z-98cb80e0/` observed two successful and zero failed maintenance reads with one authenticated connection, then removed its owned resources. The worktree was dirty and Flutter tests were concurrent; this does not verify central export, dashboard/alert wiring, failure injection or release performance.
- SMOKE_PASS with 20 independent authenticated cookie jars sharing one loopback source: `.out/roster-matrix/baseline-20-0-shared-20261109T040200Z-4b2a245c/` and `.out/roster-matrix/candidate-20-0-shared-20261109T040024Z-0dd15a66/`. Both received all initial events and cleaned up. These used a dirty driver, a dirty candidate, and concurrent Flutter tests; they do not establish physical NAT behavior, a reconnection storm or performance acceptance.
- INVESTIGATE: repeated 100-account/20-empty-room smoke after the task-owned
  AVD and builds stopped: candidate `.out/roster-matrix/candidate-100-20-20261109T044252Z-f25a4823/`
  versus baseline `.out/roster-matrix/baseline-100-20-20261109T044415Z-80ec898e/`.
  Initial maintenance p95 was 54.6 ms versus 11.2 ms; roster p95 was 33.1 ms
  versus 33.3 ms. Both completed and cleaned up, but the driver and candidate
  remained dirty, each condition was sampled once, and these are initial-event
  times rather than change propagation or a statistically controlled verdict.
  The repeated maintenance difference remains an open investigation.
- FAIL (fixture startup, no measurement): the first 5 ms candidate attempt
  `.out/roster-matrix/candidate-100-20-20261109T044757Z-3a8ad453/` found
  another QA stack using required ports. It removed no foreign resources and
  reports owned cleanup complete. Retry only when the ports are free.
- INVESTIGATE: after reducing the observer's minimum spacing to 5 ms, two
  further candidate smokes (`candidate-100-20-20261109T045416Z-4d36fb06` and
  `candidate-100-20-20261109T045654Z-6d352efd`) recorded initial maintenance
  p95 18.1 and 22.7 ms; baseline repeats recorded 11.2 and 4.5 ms. Candidate
  observer successes were 102–103 versus 85 in the preceding 50 ms run;
  final recorded DB acquires were about 2,940–2,990 versus baseline 1,953–2,010.
  These are preliminary fixture counters and two sequential samples, not a
  controlled capacity claim. All runs cleaned up. The candidate was dirty;
  before/after worktree fingerprint for the two 5 ms samples was identical
  (`9c47711aa610eac82bfc7269654cb80c26fd9d8558b3175a91be3aaa83d2d4ab`).
  Initial p95 and database pressure remain unresolved release blockers.
- SMOKE_PASS after adding bounded session/resource locks: 100 accounts and
  20 empty rooms, `.out/roster-matrix/candidate-100-20-20261109T052247Z-2b80c311/`.
  Initial p95 was 22.9 ms maintenance and 26.5 ms roster; 3,122 DB acquires and
  103 successful observer reads were recorded. The preceding 5 ms candidate
  sample recorded 2,990 acquires and 25.0 ms roster p95. Both are dirty-source
  single-run observations without real media or slow readers. The newer run's
  before/after worktree fingerprint matched
  `e0f8db4de57dc312ae47de1e8c87e0f7f696738636eebec1289791fb45e88517`.
