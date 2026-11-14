# Issue 687: Web Auto measured preflight

Status: PASS for scoped synthetic Web eligibility/transport; overall PARTIAL.
Route: T-073/T-074, experimental local Auto preparation. No server deployment.

Flagged research candidates require verified assets and a dedicated disposable
Worker. The worker measures eight synthetic warmup and 32 measured 480-sample
frames; output must stay finite and bounded. Initial conservative budgets match
native: p95 <=3ms, maximum <=8ms, aggregate <=1s. A two-second parent deadline
terminates hung initialization/inference. No microphone samples are involved.

Auto tries explicitly opted-in DeepFilter, then enabled RNNoise v0.2, then browser
suppression. Missing Worker, old model, bad assets, malformed timings or errors
reject a candidate. No hardware verdict is cached across profile preparations;
ordinary mute/unmute preserves the existing processor. Stale preparation cannot
publish after disposal. This measures eligibility, not quality or sustained load.

The normal production Auto selector remains hidden and defaults unchanged.
RNNoise v0.2 redistribution/release guards remain mandatory. Local worker/media
tests require independently prepared assets; never check models into this leaf.

Tests failed before the change for missing measurement, rejection and candidate
ordering. All 126 scoped Web noise tests and vue-tsc pass; default production
build passes with the release guards intact. Additional tests cover a hung
Worker, errors/invalid metrics/old identities, stale completion after disposal,
unchanged mute/unmute, and measured RNNoise retry after DeepFilter init failure.

Actual local WASM in dedicated Workers, eight warmup/32 measured frames:

| Browser | RNNoise p95/max ms | DeepFilter p95/max ms |
| --- | ---: | ---: |
| Chromium 153.0.8010.12 | 0.40/0.40 | 1.10/1.20 |
| Firefox 155.0 | 1/1 | 2/2 |

Both were eligible on this host. Results: local `.out/web-preflight-1114-v1.json`
in the QA checkout. RNNoise WASM SHA-256:
`f121a4c5f398e565058cdeb1301c7441c50cbed857e5898cfd39a0feaae43859`.
DeepFilter WASM/model retain the pinned identities in asset_loader.ts; only a
temporary external research-asset directory was served, no public/dist RN model.

Two Chromium runs of playwright.auto_preflight.config.ts against a private,
temporary LiveKit passed, each with worker and actual production-factory Auto
publication/mute tests: RNNoise opt-in and explicitly opted-in DeepFilter.
Capture was browser-generated synthetic input; initial publication was muted,
receiver observed nonzero finite output followed by silence below 0.0001.
The SFU binary checksum was verified before use and owned processes cleaned up.
DeepFilter worker test also passed separately in Chromium and Firefox and is
added to the existing research CI script selections for Chromium/Edge/Firefox.

Remaining: sustained overload/adaptation, product Auto UI, physical Web speech,
AEC/AGC effectiveness, hotplug/reconnect, full local feature runtime acceptance,
rights, signing and releases. These short probes do not establish quality or
capacity. CI on the new Web implementation has not yet run.
