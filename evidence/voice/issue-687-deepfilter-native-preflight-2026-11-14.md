# Issue 687: native DeepFilter worker preflight

Status: PARTIAL. VerifiedEngine now performs a synthetic preflight on its
existing worker during the first Reset, before exposing model readiness.
Eight warmup and 32 measured 480-sample frames must have finite bounded output,
p95 <= 3 ms and maximum <= 8 ms; a one-second cumulative probe deadline is
checked between calls. These are conservative initial scheduling budgets for
10 ms frames, not acoustic safety or device-wide capacity claims. A hung DLL
call cannot be interrupted by this inter-call deadline.

On success the model is recreated to discard synthetic history. Failure closes
the state and reports unavailable preparation through the existing readiness
and muted fallback path. Successful preflight is cached per engine instance;
it does not replace runtime overload monitoring or measure scheduling jitter
during a call. No synthetic frames enter the capture queue.

The new test first failed before its implementation. Fake-clock cases cover
fast/slow engines, a worst-frame spike, total deadline, failed/thrown inference,
nonfinite/clipped output and clock regression. The full default MSVC native
suite passed 24/24, including the spike/deadline assertions.

A real local libDF/model probe then reported p95 1,615 us, maximum 1,957 us,
714 ms total preparation and 300 submitted synthetic capture frames with 297
processed and zero fallback. This uses the verified native adapter, worker and
model, not a physical microphone or a LiveKit call. The model hash remains
`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
The local DLL SHA-256 was
`d94350604128a9e01641b0ed5600969c48908846a6d5fdc414361a500f11b254`.
Auto consumption, both-engine selection/adaptation, physical speech, signed
release and end-to-end acceptance remain open. No deployment or publication.
