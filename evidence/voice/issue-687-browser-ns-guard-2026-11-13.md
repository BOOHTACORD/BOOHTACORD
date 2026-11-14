# Issue 687: browser suppression guard

Baseline: master `4c923bd40625d0503afd2849f2f477c947b7fbce`. The tested
Web microphone-adapter guard and reacquisition change accompanies this record;
it does not contain RNNoise v0.2 or DeepFilterNet release assets.

Before the change, focused tests showed RNNoise was attached even when the
browser reported built-in suppression enabled or did not report its state.
The adapter now checks the source capture settings before attaching either
model. If a supported constraint is ignored, it unpublishes the muted old
track, reacquires with the requested constraints, and publishes the replacement
muted. If disabling the model constraint is rejected or remains ineffective,
it tries browser fallback. If fallback cannot be confirmed, it fails muted
instead of publishing an unverified raw track. Unit tests cover ignored and
rejected constraints, missing settings, processor failure, fallback, mute and
disposal during reacquisition, uncertain unpublication and publication failures.
An unconfirmed removal remains muted rather than creating a second publication.
These fakes do not establish live SFU behavior.

On 2026-11-14, a device-switch regression demonstrated that if a restarted input
ignores the requested suppression constraint, reacquisition previously chose
the old device and did not republish the replacement. The adapter now uses the
candidate device, republishes muted, and reports an error without retrying when
old-track removal cannot be confirmed. A Chromium test against local LiveKit
used two synthetic tones and a simulated ignored constraint: after switching,
the actual receiver observed the selected device's 880 Hz tone. This is not a
physical hotplug or speech test. The same test forced an ignored constraint
during a signalling reconnect: the selected input was recaptured, the receiver
subscribed to the replacement and received its tone. LiveKit logged its
`removeTrack` warning during that reconnect despite the passing media checks.

On this Windows host, brief headless Chromium and Firefox `getUserMedia` probes
used a physical microphone without recording or retaining samples. Chromium
reported `noiseSuppression: true` on a fresh enabled capture, but applying
`false` left it `true`; a fresh disabled capture reported `false`, and applying
`true` left it `false`. Firefox reported the requested state after both changes.
These observations are device- and browser-specific and do not prove acoustic
quality. The conservative result may still mute publication when neither the
requested mode nor browser fallback can be confirmed.

Validation: the focused capture-guard and recapture tests and production Web
build passed. Browser tests in Chromium, Firefox and Edge exercised actual
`getUserMedia`, `LocalAudioTrack` and the v0.1 RNNoise processor, with synthetic
capture and a simulated publisher: switching and mute passed, including muted
publication and stopping the old track when a replacement was needed. This is
not a LiveKit or physical speech test. Five separate synthetic v0.1 RNNoise
browser tests also passed in each browser. The first browser attempt
failed because generated v0.1 assets were absent; the existing local assets
were copied to ignored output, verified by the pinned WASM check, and the
browser tests then passed. The v0.2 model is not included.

The full `voice` real-stack and visual gate is **BLOCKED**: the local Docker
daemon did not answer a bounded probe. A separate pinned LiveKit 1.13.7
Windows server initially failed to establish a loopback ICE connection. With
signalling on loopback and ICE restricted to the host's private interface,
eight browser join and signalling-restart cases passed; four additional audio
input lifecycle cases passed through an actual receiving peer. A further test
passed in Chromium, Edge and Firefox switching browser -> RNNoise v0.1 -> off
-> browser during a live SFU call, with one publication, synthetic audio at the
receiver and silence on mute.
With the separate research bundle and opt-in flag, local Chromium, Edge and Firefox tests
passed browser -> experimental DeepFilterNet3 -> browser on the production
microphone adapter through the SFU, checking receiver audio, one publication
and mute. Firefox's simulated input may not support the browser suppression
constraint; in that case the test checks that the unsupported state is truthful.
The research model and bundle are not release-approved.
The audio lifecycle run logged LiveKit `removeTrack` warnings during reconnect;
the test assertions passed but the warnings merit separate investigation. The
SFU was stopped after each run. These are synthetic Chromium tests, not speech
quality or full product UI acceptance. A production release, physical speech
quality, end-to-end latency, long-running media and Windows native acceptance
remain **NOT_RUN**. No server deployment was performed.
