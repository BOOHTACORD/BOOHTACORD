# Issue 687: reproducible Web research bundle and local SFU

At parent source `7026885bc7df7bb9f7e54c0ba3343b61a758962c` with the changes
in this packet, the pinned Web research source was reconstructed from
DeepFilterNet `d375b2d8309e0935d165700c91da9de862a99c31`, the WorkAdventure
patch at `7e00a1b7522f044a31776fddc249a97a98de94ed`, and a pinned Cargo lock.
Two clean builds in different directories on one Windows host, using Rust
1.97.1 and wasm-bindgen 0.2.118, produced matching hashes:

- WASM: `0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec`.
- JavaScript glue: `1e6adbcb777c92a03b09051f8f43b76a382f3e0489e4ff38ec4a9ebbbae75979`.
- Model: `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.

The opt-in Vite build emitted the seven staged files byte-for-byte. A default
build omitted them, and opt-in builds rejected a missing bundle and a modified
JavaScript file. Web type checking and 35 focused unit tests passed. Chromium, Firefox and Edge 157 each passed four
research browser tests for loading, processing,
mute and invalid-model fallback against the new staged output.

Using short-lived random test keys and an isolated LiveKit v1.13.7 server,
Chromium, Firefox and Edge each passed a synthetic sender/receiver test: the
receiver observed processed audio and silence after mute. Signaling bound to loopback and
RTC candidates were restricted to the local private interface; the server and
its temporary key configuration were stopped and removed. This resolves the
previous local loopback-only ICE failure for this test configuration.

A new hosted Windows workflow is configured for the research build, opt-in
bundle and browser/SFU checks; its result is NOT_RUN until GitHub executes it.
The work does not establish independent-machine reproducibility, complete
third-party notices, physical Web microphone quality, signed delivery,
30-minute stability or production acceptance. No deployment was performed.
