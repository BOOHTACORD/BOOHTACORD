# Issue 687: Web Auto DeepFilter research

Status: PARTIAL. An explicit development-only research flag permits Auto to
select the experimental DeepFilterNet3 track processor when its separate
research flag and browser capability checks are enabled. Production builds
cannot select it through this flag. This is not a performance preflight or
adaptive policy; production Auto and Windows Auto remain incomplete.

On Windows, 109 Web noise-suppression unit tests, the Vue type check and a
normal production Web build passed.
The new tests cover the research selection, retained Auto request, initialization
failure fallback to confirmed browser suppression, and the production guard.

A local Chromium experiment used fake microphone capture, a forced 48 kHz
AudioContext, separately staged checksum-verified research model/WASM and an
isolated LiveKit server with two browser contexts. Auto selected DeepFilter,
one initially muted publication reached the receiver with finite nonzero audio,
and subsequent muted windows stayed below the existing 0.0001 peak threshold.
The short-lived server was stopped. No server deployment or model publication
occurred. This does not establish physical speech quality, processing load,
unforced device compatibility, long-duration stability or release acceptance.
