# Physical macOS audio acceptance (#257, #259)

Run from the repository on a physical Mac:

```sh
python3 -m tools.qa.macos_audio.run --mode both
```

The runner makes an isolated Flutter copy, uses the existing `ru.boohtacord.localqa` test bundle, resolves installed dependencies offline and builds Debug/Release. It owns a temporary Go/PostgreSQL/LiveKit/Tempo/Caddy stack in the local `colima-boohtacord-qa` Docker context. HTTPS/API/Tempo/SFU HTTP/TCP/UDP bind exclusively to loopback ports 4850/4851/4852/4890/4891/4895. A occupied port aborts without replacing another worker's service. Configurations stay under `.out/macos_audio` so Colima can mount them. Enter or interruption removes only ownership-labelled resources and disposable builds.

Launch the printed app path through Finder or documented Computer Use. Both apps use the production Boohtacord widgets/controllers and native CoreAudio/WebRTC bootstrap, with one QA entrypoint: it pins the owned ephemeral localhost certificate, signs into a disposable account and opens Audio Settings. Debug uses account A (administrator fixture); Release uses account B (member fixture). No fake inventory, fake permission result or fake media transport is injected. Private defines are created with mode 0600. Never publish them or either binary: the binaries contain disposable fixture credentials.

Use the real dropdowns, Join, leave/rejoin, full restart, refresh, microphone check and speaker check. Account A can save concrete builtin input/output; B can save builtin input/system-default output. The same app bundle and owned server allow the per-account preferences to be compared. To compare both roles in the same build mode, change only the private `QA_LOGIN` define and rebuild while retaining this owned stack. Do not infer alternate physical device behaviour from two aliases of one endpoint.

The only exported diagnostic preference is `flutter.qa_mac_audio_state` in the QA app domain. Read that exact key; never dump the whole preference domain. It contains phase, scan state/failure, inventory counts, selected/not-selected booleans and warning/error presence. It contains no device IDs/labels, account IDs, cookies, passwords or audio samples. Export it before each restart if needed. It is observations, not a PASS oracle.

## Physical closure conditions

For #257, observe the actual waiting frame, real microphone denial/restriction, real initialization/enumeration failure and successful empty inventory, then permission recovery through System Settings without restarting, in both modes. Component tests cover distinct strings but cannot close these physical rows. Changing system privacy policy requires the applicable UI confirmation; do not silently clear TCC or introduce system-wide restrictions. A machine that already succeeds has not exercised the denied/restricted/error/empty branches.

For #259, record actual input capture and remote hearing through the saved output on first Join, leave/rejoin and full restart before Room creation. Compare A/B, disconnect a removable saved endpoint and observe fallback/reappearance, and check that local device checks and processing changes preserve active routing. A microphone level or successful SFU connection does not prove remote hearing. Builtin-only hardware cannot prove USB/Bluetooth hotplug.

Record every row PASS/FAIL/NOT_RUN and the observed build, model, OS and endpoint types. Keep both issues open when any required physical row is missing. Capture through a documented screenshot API; if no file export exists, identify the inline Computer Use capture and record visual observations without inventing a PNG path or hash. Do not preserve raw device labels in public evidence. No application behaviour, requirements, backlog or server contract changes are made by this harness.
