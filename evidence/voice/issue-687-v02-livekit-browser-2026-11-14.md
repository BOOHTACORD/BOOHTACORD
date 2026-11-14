# Issue 687: experimental RNNoise v0.2 browser/SFU probe

On Windows, the checked-in Web microphone adapter was exercised with the
experimental `VITE_RNNOISE_V02_ENABLED=true` flag and a locally prepared,
checksum-verified research bundle. The existing model and manifest were copied
temporarily into ignored local browser assets; no model file was committed or
published. The WASM SHA-256 was
`f121a4c5f398e565058cdeb1301c7441c50cbed857e5898cfd39a0feaae43859`.
The temporary public asset directory was removed immediately after testing;
the existing local Web build contained no v0.2 directory.

Chromium, Edge and Firefox each passed a synthetic microphone test through an
isolated local LiveKit 1.13.7 server: browser -> RNNoise -> off -> browser,
with the effective model explicitly identified as `rnnoise-stock-v0.2`,
one audio publication, received synthetic audio and silence after mute. The
fixture handles an unsupported browser-suppression constraint explicitly.
The server was stopped after each run. The test adds the model-identity check
to the checked-in SFU switch test; v0.2 requires separate local research assets.

The v0.2 loader now requires a separately configured build-time WASM SHA-256;
missing values and manifest mismatches fail before a WASM download, and a
changed trusted digest does not reuse a cached module. The three-browser SFU
probe was repeated with the verified digest configured. The default Web build
completed afterward with no v0.2 asset directory. This binding does not sign
the JavaScript, manifest or binary and is not a trusted delivery or rollback.
Production Vite builds now reject both an enabled v0.2 flag and a leftover
v0.2 public asset directory. Both failure paths and the normal build were
checked locally; the guard does not establish distribution rights.

This is not a physical speech, quality, long-duration, device, native Windows,
or release acceptance test. The source model's redistribution terms remain
unconfirmed; the local test does not grant permission to distribute the weights.
No production release or server deployment was performed.
