# Issue 687: native artifact loading experiment

The Windows file verifier checks a local absolute path, rejects directories and
final-component reparse points, bounds size, verifies SHA-256 and retains a
handle without write/delete sharing. Tests cover a Unicode path, wrong hash,
oversize input, relative path, and write/delete attempts while the handle is
open. The module loader checks that hash before loading and searches System32
for dependencies; a fixture verifies a rejected hash never loads the module.

These checks do **not** authenticate ancestor directories or prevent their
replacement between hashing and `LoadLibraryExW`. They are not a complete
release trust boundary. Signing, an appropriate stable installation path,
reparse-point/ancestor threat assessment and update behavior remain open.

The noninstrumented Rust research DLL built with
`-C target-feature=+crt-static -C link-arg=/Brepro` had SHA-256
`a7d07b7b2231b5ed4afa5b3a2a1a812054cea5a25e007b27b5a309cf2a421f48`.
Two independent target directories on this host and source path yielded that
same DLL hash and the same synthetic output fingerprint. Cross-machine and
cross-source-path reproducibility remain unverified.
`dumpbin /dependents` listed Windows system libraries only, with no separate
VC Runtime or UCRT dependency. Its 220-frame synthetic output matched earlier
research builds. The verified-engine/adapter probe submitted 300 synthetic
frames, processed 297 and reported no fallback, including with the model in a
path containing Cyrillic characters. A wrong DLL hash failed before model
initialization. MSVC CTest passed 18/18.

This was a prewarmed three-second test with a stub WebRTC interface, not an
installed application, physical microphone, signed release, acoustic study or
sustained load test. Normal Windows client construction does not instantiate
the verified engine; the model and DLL are not delivered in production.
