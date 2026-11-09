# Issue 689: comparable realtime load matrix

**Route:** disposable local load fixture and bounded roster workload.

- [x] Test and support independent 0..20 synthetic voice rooms without altering existing logical voice capacity profiles.
- [x] Implement a bounded public connection driver that rejects private events and checks fixed-scope connection counts.
- [x] Add a 20-account shared-source profile with independent cookie jars and explicit result classification.
- [x] Run shared-source smoke profiles against baseline and candidate; this is not a physical NAT test.
- [ ] Repeat shared-source comparison without concurrent workloads on immutable builds.
- [ ] Run and compare the 100-public-connection scenario on immutable sources without concurrent workloads.
- [ ] Implement an ownership-guarded, bounded workload with equivalent legacy and candidate clients.
- [ ] Capture resource and latency measurements with immutable source and artifact identities for each matrix cell.
- [ ] Run the specified user/room matrix and fault, guest, NAT and reconnect cases on comparable local infrastructure.
- [ ] Investigate threshold failures; never infer media capacity from API-only traffic.
