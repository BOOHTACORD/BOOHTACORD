# Bounded SFU snapshot measurement

Status: PASS. Date: 2026-10-05. Issue: #81.
Executor: GitHub Ubuntu 24.04; owned Go/PostgreSQL/LiveKit fixture.
Source merge: `c1a9041f379176fa7a27556552498fded39cfa8d`.
Head: `ff834bc858589f51d4fbe692670838cd0c5de77f`.
[Actual measurement](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37364698318).

| Virtual authenticated HTTP observers | Actual RoomService calls | Calls/sec | HTTP p95 ms |
|---|---|---|---|
| 1 | 1 | 144.231 | 6.542 |
| 20 | 1 | 20.186 | 35.581 |
| 100 | 1 | 5.383 | 51.585 |

[The uncached baseline](sfu-snapshot-baseline-2026-10-05.md) measured 1/20/100
actual calls. Measurements justified single-flight and a 250 ms metadata TTL.
The retained scope is bounded to one canonical room set; maps are copied.
Authentication, initial/final PostgreSQL visibility and no-store remain per response.
Canceled callers do not cancel other callers' shared fetch; its deadline is 3 seconds.
Expired snapshots are discarded. SFU outage after TTL returns 503; recovery returns 200.
The harness explicitly expires TTL before asserting unavailability, including fast shutdown.

Raw receipt: local `critical-next-five-issues/sfu-final/report.json` and run artifact.
API SHA-256: `ed9989110d675a3be05196d14269460d57c2c5fc57b03ae71e57bc1f6024d9eb`.
Owned resources removed; no production volumes or accounts used.
These observers share an authenticated session and query one absent SFU room.
This is HTTP fan-out evidence; it proves no publisher count or physical media capacity.
Live cached account/lease visibility is covered by focused tests and the separate client receipt.
