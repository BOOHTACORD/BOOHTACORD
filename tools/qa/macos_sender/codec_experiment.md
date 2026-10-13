# Native codec experiment (#331)

This module extends the existing physical Mac sender harness. It does not change
production VP8, enable simulcast/backup encoders, or prove a hardware encoder.
The Python planner and Dart capability tests are preparation, not device evidence.

Before admitting a run, retain #329 stage baseline and the stabilized #330 capture
snapshot. Both codecs must use identical application/capture/vendor source,
SDK/build flags, source pixels/pattern, profile, bitrate ceiling, receiver,
network/power conditions, 30-second warm-up and 180-second measurement window.
The prepared matrix alternates AB/BA for three pairs per window/display and
720p60, 1080p60, 1080p30 cell. Missing controls invalidate a comparison.

`apply_private_codec_overlay` accepts only the existing producer's marked private
Flutter copy and an exact expected composition SHA. It injects one QA driver
into private composition and records before/after source digests. Capture and
stop use the same production driver; both paired builds use the same injected
source. This overlay is not production lifecycle acceptance. Publication-specific
codec differs only via `QA_NATIVE_CODEC=vp8|h264`; without this variable the driver
delegates unchanged behavior. Quality changes during an experimental publication
are rejected; use a fresh fixed-profile run.

The coordinator sets `QA_NATIVE_CODEC_PHASE_ADMITTED=1` only after baseline/path
readiness. `QA_NATIVE_CODEC_CAPS_FILE` points to `codec-receivers-private.json`
in the marked owned directory. Schema 1 has `measured: true` and
`receiver_capabilities`, a nonempty list of actual `getCapabilities('video').codecs`
snapshots, one per target receiver. Record their actual runtime versions and
capture timestamps in the run receipt; do not reuse snapshots across changed
browser/SDK builds or substitute fixture capabilities for device admission.
The host validates the canonical mode-0600 capability file and ownership marker,
then optionally transports its normalized allowlisted rows through
`QA_NATIVE_CODEC_CAPS_B64` and `QA_NATIVE_CODEC_CAPS_SHA256`. The bounded schema-1
envelope includes `ownership_proof` (marker SHA and original measured-file SHA).
It does not grant sandbox file access or change entitlements. Unknown fields,
raw SDP, unknown codecs, missing ownership, corrupt SHA and oversized input fail.
In this mode the adapter emits bounded `QA_CODEC_DIAGNOSTIC ` JSON stdout records
with `event: admission|readback`; the host preserves them in the fresh run.
Admission contains safe phase/reason/error-class/known errno, capability counts,
connected-room state and SFU list classification, never paths or exceptions' text.

The SFU allowlist is read from the actual connected room. A null list is unknown;
an explicit list still restricts codecs. Only after an observed connected empty
list and source-bound SDK semantics proof may the coordinator explicitly set
`QA_NATIVE_CODEC_SFU_EMPTY_ADMITTED=1`: this means no explicit SFU restriction,
not measured SFU codec support. Known sender/receiver intersection and actual
negotiated readback remain mandatory. The flag cannot bypass null, disconnected
room or an explicit incompatible list.

Only known constrained-baseline H.264 `42e0` levels and packetization-mode 1 are
admitted in this prototype. Level compatibility is separate from profile
compatibility per RFC 6184 section 8.2.2; the gate records a conservative common
level without modifying SDP. Negotiated codec/FMTP must be read back from the
used outbound codec and fresh native sender parameters, rather than the
requested option or cached track codec. Missing/mismatched readback fails within
the bounded verification window and is not relabelled as a fallback measurement.

Keep source/SDK/SFU digests, stage distributions, actual codec/profile and
single-layer topology in receipts. Keep high-cardinality track/sender identifiers,
raw SDP and credentials private. Encoder implementation labels and capabilities
are not hardware proof. GPU/thermal/hardware fields remain unknown when no
independent measurement establishes them. Loopback Chrome/Safari does not prove
physical Mac-to-Mac or other released receivers. Policy rollout remains disabled
until paired metrics, compatibility and an approved support-envelope ADR exist.

In legacy file mode the QA adapter writes an atomic allowlisted
`codec-negotiation-private.json` beside the owned capability file before confirming
or rejecting readback. Environment mode emits the same sanitized readback via
stdout instead, including the payload SHA; it performs no external receipt I/O. The
caller must archive/delete that file before each case and bind its hash to the
fresh run, including failed/deferred attempts. Codec MIME spelling is normalized
only for known VP8/H264. Profile rejection keeps the actual codec/FMTP and fresh
encoding limits; no track IDs, raw SDP or encoder hardware claim are exported.

Native diagnostics off/on is a separate overhead experiment. Codec pairs require
the same explicitly recorded boolean `capture_diagnostics_enabled` control;
unknown, differing or non-boolean values invalidate comparison. The QA-only
`QA_NATIVE_CAPTURE_DIAGNOSTICS=0|1` capture override changes only that nullable
SDK option and delegates the normal production capture path. Absent override
preserves existing options; invalid values fail before capture. With diagnostics
off, native counters are unavailable rather than invented measured zero.
