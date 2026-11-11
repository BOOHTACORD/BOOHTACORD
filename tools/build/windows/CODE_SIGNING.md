# Windows Authenticode preparation

The normal Windows build remains unchanged when signing is not configured.
The prepared signing path is opt-in; no workflow credentials or production
release settings are changed by this implementation.

For a controlled signing environment, provision a trusted code-signing
certificate and accessible private key in the build user's Windows `My`
certificate store. Configure `WINDOWS_SIGN_CERT_SHA1` with the public 40-digit
certificate thumbprint and `WINDOWS_SIGN_TIMESTAMP_URL` with the provider's
HTTP or HTTPS RFC 3161 timestamp endpoint. Both are required together. Some
Windows SDK SignTool versions reject HTTPS URLs; HTTP exposes the digest to the
timestamp service and network, but the timestamp response is signed and its
trust must be verified. Do not put a
private key, password or access token in command-line arguments, repository
files or logs. `signtool.exe` must be on PATH or in the installed Windows SDK.

Run the existing `python -m tools.build.windows.run` on Windows in that controlled
environment. Before generating the manifest and archive the build signs each
unsigned application EXE/DLL and validates every binary; pre-existing trusted
third-party signatures are preserved. The main EXE and newly signed binaries
must use the selected certificate and have a timestamp. Velopack receives the
same signing parameters for its generated bootstrap and installer. Packaging
fails if the installer signature is invalid, if an unknown binary is introduced,
if either allowed Velopack bootstrap is untrusted, or if any packaged application
binary differs from the previously verified release directory.

The production workflow does not yet provision a certificate or set these
variables. Before enabling signed publication, run an exact-source Windows
release candidate with the actual provider, verify trusted timestamps on all
distributed binaries and installer, and exercise installation and launch on a
Windows machine with Smart App Control enforced. Confirm the affected user's
CodeIntegrity event separately. A self-signed test certificate cannot establish
Smart App Control compatibility.
