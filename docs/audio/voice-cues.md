# Voice event cue provenance

The four default cues are original procedural sine-tone designs introduced for
BOOHTACORD, dedicated under CC0-1.0. They contain no third-party recordings or
sampled melodies. Web and Flutter synthesize the same mono 24 kHz, signed 16-bit
PCM WAV locally; no recording or network media transport is involved.

Join/leave use two 100 ms notes; publisher start/stop use three. The shared
SHA-256 fixtures in `contracts/voice-sound-pcm.fixtures.json` are enforced by both
client test suites. Micro-unit quantization and the same final rounding rule
avoid language-specific half-sample differences. This is source audio design,
not a checked-in generated-media artifact.

Personal uploads are separate private user content. The isolated server worker
validates and normalizes them before clients can use their resource IDs.
