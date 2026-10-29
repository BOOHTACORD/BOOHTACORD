# Owned local media-report correlation verification

This packet verifies the backend facet of I240.C17 using normal local HTTP,
real PostgreSQL and existing controlled accounts. The criterion remains NOT_RUN
pending root review; complete acceptance is not inferred from this supplement.

Run commands, in order, from Q:

1. python -B -X utf8 .out/qa-owned-media-correlation/preflight.py
2. python -B -X utf8 .out/qa-owned-media-correlation/run.py
3. After cleanup/window release: python -B -X utf8 .out/qa-owned-media-correlation/seal.py

The exact leaf is observability/report_client_screen/api. Source and controller
hashes precede fixture mutation. Three named current-CI tests are retained in
native-ci.json; none is rerun. The local API image declares source072; the five
core leaf files match merged754b through LF hashes.

Four fresh owned API sessions (A twice, B, administrator observer), one nonce
category/VOICE and two sequential logical leases are the complete mutable
fixture. No new users, chat data, RTC credentials or connected media are used.
Every resource request is prejournaled; a failed/uncertain create is never
blindly repeated. Private ownership/session/trace artifacts remain private.

The matrix checks active owned204, other-account/sibling-session/unknown/revoked
handle409, malformed400 and expired own session401. Three accepted reports test
ordinary derived correlation, a forged media header and an omitted handle.
Rejected reports must preserve the latest anonymous sample. Accepted reports
must match the bounded numeric diagnostic payload without exposing handles.

Proper telemetry-session/visit/flow headers bind the real exported media.sample
spans. A unique owned visit isolates the Tempo query. Public results contain only
counts and equality booleans. Prometheus must observe exactly three added
fixed-enum report-counter events; no identity-valued metric selector is used.
Unobserved export remains PARTIAL; neither trace payload nor exporter is forged.

Source voice_leases has no expiry/heartbeat column. Only the freshly owned A2
session expires_at is changed with exact ID/account/digest guards. HTTP401 proves
expired-session admission refusal. Normal sibling session revoke cleans that
session and lease; this is not standalone lease-TTL acceptance.

Normal release/logout/revoke precedes exact fixture SQL teardown. Selected table
fingerprints and nine service identities/configuration/start/restart values are
compared. Chat tables, previous packets and source/controller bytes are preserved.
Expected finite diagnostic aggregates/traces and monotonic audit/topology effects
remain; no recorder reset or entire-database equality is claimed.

No production, browser/CUA/ADB/device action, native/physical media acceptance,
load, clock/global-config change, service control or source fix occurs. Only the
closed public-review.json allowlist may be exported; private/** and raw logs are
excluded. Terminal results and exact limits are in summary/runtime/observer and
cleanup metadata rather than being implied by this procedure description.

Actual first execution: all ten HTTP/PG controls passed. Tempo exported exactly
three owned media.sample spans, each with matching authenticated account/session
and visit/flow/attempt; seven rejected flows exported none. The forged media
header did not override the derived lease ID, and omission remained uncorrelated.

Overall result is PARTIAL: the Prometheus selector returned an empty vector both
before and after the36.578s observer window. The original observer's numeric zero
delta represents that empty-vector sentinel, not a measured zero counter or proof
of backend metric loss. No report was replayed, exporter fabricated, recorder
reset or follow-up API request made after the exclusive mutable window release.

Cleanup passed: four owned sessions revoked with live401 readback and removed,
all owned lease/work/category/VOICE rows removed,14 selected fingerprints and
nine services/source/prior packets preserved. Topology49→51 and five metadata
audit receipts remain intentionally. The full criterion awaits root review.
