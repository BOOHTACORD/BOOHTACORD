# Physical Android screen share on production

Outcome: **PARTIAL**. Samsung SM-A576B / Android 16 / API 36 published an
app-only Settings window through `https://v.bootybay.ru` in `SHARE_TEST`.
Visible Chrome 155.0.8059.85 on the physical Windows PC decoded changing
590x1280 frames. The native Windows client remained on connecting/first-frame
states in the observed attempts. Its exact failure cause is unresolved.

## Exact candidates

- Android 1.0.45, versionCode 2080, source `9c221897fdefec8098f707d61ca5b6e8b28bb0bd`.
  Installed APK SHA256 and signing certificate match the official arm64 release.
- Windows 1.0.47+82, source `f5cd783518349e2f79a78910a91908882ba87cc1`.
  EXE, app snapshot and WebRTC DLL match its installed release manifest.
- Production Web 1.0.47, source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.
  API health returned 200; the API binary source was not independently verified.
- No new APK was installed. The unused local QA build configuration was restored.

## Protection and execution mapping

| Protection | Execution / command | Platform | Required when | Result |
| --- | --- | --- | --- | --- |
| An authorized phone can publish an app-only screen and a separate member can view real frames | BOOHTACORD Start share → system Show app → Settings; Chrome login → SHARE_TEST → Without microphone → Watch screen; real `RTCPeerConnection.getStats()` | Physical Samsung Android 16 → visible Chrome on Windows | Android capture, SDK, publication or receiver changes | `browser-outcomes.json`, two `decoded-display-*.png`, `result.json`: scoped PASS |
| Stopping capture releases the screen foreground service while retaining voice | Stop share; `adb shell dumpsys activity services ru.boohtacord.app`; `adb shell dumpsys media_projection`; inspect Web publication controls | Physical Android + production Web | Capture/FGS lifecycle changes | `result.json`: screen service removed, microphone service retained, watch button removed; complete renderer cleanup NOT_PROVEN |
| A new app-only capture can be admitted after Stop and viewed by a fresh listener | Repeat system app-only consent and Watch in a fresh controlled browser session | Same physical phone/PC | Republish or lifecycle changes | `restart-observations.json`, `decoded-restarted.png`: scoped PASS; same-subscriber auto-recovery NOT_RUN |
| The released native Windows viewer actually displays a phone frame | Windows BOOHTACORD → SHARE_TEST → Watch screen; inspect player state | Physical Windows native 1.0.47+82 | Windows viewer/SDK or shared media contract changes | `result.json`: FAIL in observed attempts, numeric decode counters UNKNOWN |

## Observations and visual review

The publisher was in the background while the selected Settings app was in
the foreground. Android reported separate microphone (`0x00000080`) and
screen (`0x00000020`) foreground-service types. After Stop, only microphone
remained and the app no longer owned a MediaProjection. Voice stayed connected.

Chrome decoded 30 then 54 frames while the source was scrolled. The two original
decoded frames were inspected at their native 590x1280 resolution: the scroll
positions differ, text remains readable, and no obvious stride/color corruption
was seen. The deliberately scrolled viewport is not an assertion of full-display
capture. After republish, a fresh observer decoded another 31 frames at 590x1280.

The source is static between gestures. Retained freeze counters increased;
these observations do not establish steady FPS, unique source-frame delivery,
glass-to-glass latency, hardware audio quality or a 720p/1080p x30/60 profile.

The operator reported excluding the phone from Xkeen, then withdrew certainty
that this restored playback. No controlled routing A/B was performed. Xkeen
causality and a Windows-code root cause both remain UNPROVEN.

## Privacy, reproduction and gate boundaries

Use separate authorized accounts in the existing test room. Do not capture a
chat, account page, private notification or unrelated app. Captures here are
original decoded frames obtained with `canvas.drawImage(video)`; player overlays
and participant labels are absent. An initial account-root capture was discarded.
No continuous video/PCM, credentials, participant IDs or DM contents are included.

The controlled listener uses normal HTTPS, secure cookies, Origin and room ACL;
no successful API replies, media packets or connection flags were mocked.
The phone's installed session and release were preserved. No production service,
router setting, account role or phone setting was changed by this packet.

Related gates [#132](https://github.com/Egkurilov/BOOHTACORD/issues/132) and
[#173](https://github.com/Egkurilov/BOOHTACORD/issues/173) are not closed by this
scoped run. macOS/Pixel/emulator coverage, permission denial, muted cases,
physical audibility, full lifecycle/cleanup and the quality matrix remain open.

At handoff, the user-requested phone share and visible controlled Chrome viewer
remain running in SHARE_TEST. Closing that browser ends its controlled listener.
