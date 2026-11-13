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

The first hosted run on source `37ef9043ae8d9aa448716ba43dd725ed7c9ec04b`
failed before the Windows builds because Python 3.12.15 is unavailable for
Windows 2022. It also exposed a CI cache-policy mismatch and an import verifier
that did not recognize TypeScript extension substitution or the two generated
worklet dependencies. This packet uses the project-approved Windows Python,
adds the research workflow to the locked npm-cache contract, and limits the
Windows Playwright exception and generated-import mappings to their exact
owners. The corresponding local policy and dependency tests passed; hosted
results for the subsequent commit remain pending. On the local Windows host,
two unrelated Linux-specific runner guest-update tests could not run because
Perl/LXC were absent; the focused action-pin suite passed separately.

Hosted source `2baf02dfe317acaf375e8811716b356477f98544` passed the
frontend fast checks but contracts discovered the speech metric tests without
their Python dependencies. The shared CI requirements now use the same exact
audio pins, checked by a focused test and the reviewed input inventory. Local
toolchain policy and speech metric tests pass; the new hosted run is pending.

Hosted source `2baf02dfe317acaf375e8811716b356477f98544` exposed
a cross-machine WASM hash mismatch. Inspection of the first artifact found
absolute Cargo registry paths in the binary. Compiler remapping and a byte-stable
source overlay produced matching SHA-256 `9e7d6eb2932f903a1d599288c5a57fe8dd510f2f5917441968e915adc5cf3caf`
in two local builds with different source and Cargo directories; no local path
strings were found. This does not yet prove reproducibility on a second host.
The opt-in Web build and four experimental tests per Chromium, Firefox and
Edge passed locally with the new module. Physical microphone and listening
acceptance remain NOT_RUN. Hosted confirmation remains pending.
The local LiveKit synthetic sender/receiver/mute test also passed again in
all three browsers with the rebuilt module; it is not a physical microphone test.

Hosted source `41288a36909c242989623829c26fabd85ea9ccfa` rebuilt and
verified the pinned WASM on an independent Windows runner; Chromium research
tests passed. Firefox on that runner timed out in three audio graph tests after
its loader passed. On Linux, the separate Firefox direct WebRTC test observed
a nonzero received peak during its post-mute window. The causes are UNKNOWN.
The local Firefox versions of both scenarios passed; that does not override CI.
Bounded AudioContext readiness and aggregate peak diagnostics were added without
relaxing the silence assertion. New hosted diagnostics remain pending.

On hosted source `d85b65c740d5edfcad22f09436cc21fdd29d0aa7`,
Windows Firefox reported `AudioContext resume timed out; state=suspended`;
`Audiosrv` and `AudioEndpointBuilder` were both stopped. Chromium passed.
The workflow now starts those services in its disposable runner before the
audio checks; hosted verification of the change is pending. Linux Firefox
passed the strict mute test on this run; ten repeated local Windows Firefox
peer tests passed, so the earlier Linux result remains intermittent and its
cause is not established. The separate lifecycle CI reported failure after
`roster-transport-restored`; the public artifact contains no further diagnosis.

On hosted source `d7f788fd3ba8b9e4698e5e9eedbc6748a129d021`, both
Windows audio services were running but Firefox still timed out with a
suspended AudioContext. Starting services alone did not fix the failure. A
local forced-null-context experiment likewise produced no progressing audio
clock, so it is not used as a passing substitute. The research workflow now
keeps Chromium and Edge on Windows and runs Firefox graph and local LiveKit
tests on Linux with a private PulseAudio sink and a checksum-verified bundle
from the same workflow run. Hosted validation of this change is pending.

Hosted source `2d8043531d4dfd2ccaa9a9654642d7cb398ce166` passed
the Windows Chromium/Edge research job and all four Firefox graph checks on
Linux. The Firefox LiveKit test failed during peer connection on the loopback
Docker fixture. The Linux fixture now uses a selected private interface for
ICE, loopback-only signaling, explicitly bound UDP, and ephemeral credentials.
Hosted verification and a working Firefox/SFU test remain pending.

Hosted source `87205a0eb8fe30130933156d4954fd65b6b2be35` connected
Firefox to the private-interface SFU and received nonzero processed audio,
but produced no meter windows after mute. The test meter previously ignored
render quanta without an input channel. It now counts those quanta as missing
input and measures their silent output while the graph clock advances; a unit
test covers both absent and nonzero inputs. The SFU test additionally checks
the muted local track, disabled processor output, connected room and finite
post-mute output. Local Firefox and Chromium SFU tests passed with the changes;
hosted verification remains pending. This is not physical or listening proof.
