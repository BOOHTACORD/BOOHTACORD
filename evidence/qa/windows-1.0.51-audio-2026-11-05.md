# Windows 1.0.51 audio investigation — 2026-11-05

- Installed client: `1.0.51+87`; installed executable and relevant audio
  libraries match the `windows-v1.0.51` release manifest.
- The user reported voice connected, but neither remote audio nor microphone
  worked in voice channels. End-to-end voice reproduction: **NOT_RUN**; no
  independent test participant was available.
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
- Corrected local-test routing and focused Flutter tests: **PENDING**.
- Native Windows build and physical voice acceptance: **NOT_RUN**.
