# Android voice network-loss baseline — 2026-11-06

- Device: physical Samsung SM-A576B, Android 16; official signed Android
  1.0.51+2087, source revision `4410aa123effef00887d93606a5e510c6b2e36e1`.
  The release APK hash and signing certificate matched the installed app.
- With a muted microphone, the native client joined an empty test voice
  channel. Wi-Fi and mobile data were both disabled for 125 seconds. Android
  reported no active default network; production services were not restarted.
- At 40, 80 and 125 seconds without a default network, the phone still showed
  `Голос подключён` for the original channel. The separate server-unavailable
  banner was visible. This is a **FAIL** for truthful voice recovery status;
  no audio/RTP was recorded or inferred from the indicator.
- After Wi-Fi and mobile data were restored, the UI showed recovery and
  returned to the original channel between 15 and 20 seconds after restoration.
  The microphone remained muted. A separate Windows client showed the phone in
  the test channel's roster. This is a scoped client-network-outage result,
  not proof of media audibility, server restart handling or JWT/lease renewal.
- After the run, both original network settings were enabled, the test voice
  channel was explicitly left, and the independent restoration guard had exited.
  The Windows user's existing voice session was not moved or restarted.
- Windows/macOS/iOS, 5/15-minute outages, server-only failures, paired media,
  manual-leave races and production deployment acceptance remain **NOT_RUN**.
