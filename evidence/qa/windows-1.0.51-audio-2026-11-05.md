# Windows 1.0.51 audio investigation — 2026-11-05

- Installed client: `1.0.51+87`; installed executable and relevant audio
  libraries match the `windows-v1.0.51` release manifest.
- The user initially reported voice connected, but neither remote audio nor
  microphone worked. On a later join to an occupied channel, the user confirmed
  hearing participants and being heard on the unchanged installed 1.0.51.
  The original failure's trigger and whether it recurs remain unknown.
- Local microphone test: the user observed a changing input level. This does
  not establish that microphone audio is published or heard remotely.
- Local speaker test: the user did not hear the signal on the Logitech
  headset. Windows had the headset as default output, system volume 62%,
  and BOOHTACORD volume 100%; the user reported other applications audible.
- The saved output ID is not a SoLoud integer. The installed SoLoud device
  list orders Jump Desktop Virtual Speaker before the Logitech headset.
  Replaying the original label comparison against that list selected the
  virtual device instead of the headset: **FAIL**.
- A separate direct SoLoud test selected the Logitech device. Its process
  audio-session peak reached 0.06006; the user reported no audible signal.
  A mixer peak is not proof that the headphones emitted sound.
- Compared 1.0.50 to 1.0.51: the native Windows WebRTC, SoLoud and record
  DLL code sections and `libwebrtc.dll` match; the 1.0.51 audio-coexistence
  change adds Windows guidance. Earlier 1.0.50 changed voice recovery.
- CI run 42096785598 on commit `4ad755d4f` passed the three focused output
  resolution tests and the existing local device-check tests; its Windows
  distribution build passed. Flutter analysis failed on internal-constructor
  warnings in the new fixtures. CI run 42098603324 on commit `a74a689d3`
  passed Flutter tests and analysis after the fixture warning fix: 1,762 app,
  450 LiveKit, and 34 WebRTC tests passed; each of the first two suites skipped
  three tests. The Windows build, native tests and GUI/SFU screen-setup gate
  passed; that gate does not establish physical voice-audio acceptance. Its
  contracts job requires a parity-review update, added in the next revision.
- Local `check.sh --feature settings --base origin/master --real-stack` was
  blocked by the Windows `python3` app alias. Invoking the runner with Python
  reached the web stages, but web unit and build were blocked; the incomplete
  attempt was stopped. No physical or real-stack acceptance is claimed.
- Installed-client validation of the patched candidate: **NOT_RUN**. The
  later user-reported successful voice exchange used the unchanged 1.0.51.

## Current-master integration, 2026-11-08

The branch was combined with master `cc5d3992d`: the split speaker check retains
the master's process-wide `SoundEngineLease` acquisition and final release.
The exact-label/ambiguous-fallback resolver and existing Android route behavior
remain covered. Fourteen focused resolver/device-check/queue tests passed on
Windows. This source validation does not establish acoustic output; physical
audibility on the patched candidate remains NOT_RUN.
