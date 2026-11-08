# Join sound storage and normalization

Backend source packet: `internal/voice/join_sound` with migration `0067_join_sounds.sql`.
Real temporary PostgreSQL: PASS for room/session-scoped reads, revoked-session rejection, upload admission and replacement invalidating the old resource ID.
Real FFmpeg/ffprobe 8.0.1: PASS for WAV/MP3/OGG normalization to MP3 and rejection of synthetic HTML, short and long input. Encoded output is checked for measured loudness and true peak, and ID3 metadata is disabled.
Commands: `go test -v -count=1 -tags soundprocessor ./internal/voice/join_sound/... ./internal/database/migrate` with both test database variables set to the owned loopback instance. Explicit FFmpeg tests require the `soundprocessor` build tag; ordinary unit CI does not prove transcoding.
All requested package tests passed with no skips; repeat migrations passed. The owned PostgreSQL container was stopped automatically.
The processor is not yet exposed as an isolated deployment worker; production API routes and client playback are not connected by this packet. CPU/memory/container isolation, full endpoint authorization, adversarial decoder containment, native audio and release acceptance remain NOT_RUN. No deploy or merge claim.
