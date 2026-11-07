# Join-sound HTTP and isolated worker packet

HTTP lifecycle and real FFmpeg: PASS using a disposable PostgreSQL instance and
an HTTP worker. Upload, exact-Origin denial, owner preview, disable and deletion
were exercised. Authentication in this integration target uses the existing
test authenticator; a complete real-login/product-client journey remains NOT_RUN.
Target: `go test -v -count=1 -tags soundprocessor ./internal/voice/join_sound/...
./internal/app/voice_sound_routes ./internal/database/migrate` with both owned DB
variables configured. All selected tests passed without skips.

Container: PASS via `tools/qa/join_sounds/container_smoke.sh`. Real FFmpeg 6.1.2
returned a bounded MP3 over an internal Docker network. UID 65532, read-only root,
256 MiB memory and 64 PIDs were verified. Owned containers/networks were removed.
An initial BusyBox upload fixture was rejected at inspection; the final fixture
uses curl's binary-body mode. An initial host-port attempt could not reach the
internal network; final proof uses a separate client container on that network.

The source adds a default-disabled worker endpoint and optional Compose overlay.
Signed delivery integration, actual client controls/playback, physical audio,
full abuse/decoder-containment tests and production deployment remain NOT_RUN.
No complete #676/#678 acceptance, merge or release is claimed.
