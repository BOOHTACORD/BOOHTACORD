# External music during BOOHTACORD voice sessions

BOOHTACORD must not deliberately reduce another application's volume when a user enters a voice channel.

## Platform policy

| Client | App-controlled change | Limitation outside the app |
| --- | --- | --- |
| Android | The **LiveKit-owned** native `LKAudioSwitchManager` defaults to `manageAudioFocus=false` from creation, before the first voice session; it retains `inCommunication`, speech routing, and microphone capture. Dart's communication preset also keeps focus disabled on connect. | Bluetooth mic use can switch a headset from A2DP stereo to HFP/SCO, lowering *quality* without changing its volume slider. Other apps and OEM policies can independently pause playback. |
| iOS | Automatic `playAndRecord` and native fallback include `mixWithOthers` and not `duckOthers`, while preserving the speaker/Bluetooth options; playback-only already mixes. | OS/device routing and Bluetooth profile changes cannot be overridden by these flags. |
| Windows | Native client shows how to disable **Windows Communications** attenuation; does not change system-wide policy or other programs' volumes. | Control Panel → Sound → Communications → **Do nothing** (`Панель управления → Звук → Связь → Действие не требуется`). This is Windows policy, not BOOHTACORD's participant volume. |
| Web | On Windows the audio settings show the same OS guidance. | Browser APIs cannot change Windows Communications policy or mix with Bluetooth audio routing controls. |

## Physical acceptance (NOT_RUN)

1. Start music in a separate app at a fixed player and system volume, e.g. 50%, using one known audio-output device. Record levels before the call.
2. Open BOOHTACORD, join **listener-only**, then **with microphone**, mute/unmute, change voice channels, reconnect, and leave. Measure music levels and check that external player and system volume sliders did not change.
3. On Android check `manageAudioFocus=false` before first voice join and throughout reconnect. On iOS check `mixWithOthers` and uninterrupted music with a live microphone.
4. On Windows test *both* native client and Web using **Communications → Do nothing**; contrast with Windows default policy, reporting system ducking separately. The presence of the help text is not proof that audio is fixed.
5. Repeat with wired headphones, built-in speakers and Bluetooth. Record HFP/A2DP profile switches separately from actual attenuation. Verify remote speech and microphone still work.
6. Capture device, OS version, speaker/headset/driver, build SHA, measured before/during/after levels, screenshots/audio captures, and PASS/FAIL for each environment.

Automated unit/source tests alone do **not** establish physical audio acceptance. Do not mark this as a completed cross-platform regression until it has been run.

References: [Windows stream attenuation](https://learn.microsoft.com/en-us/windows/win32/coreaudio/stream-attenuation), [Android audio focus](https://developer.android.com/media/optimize/audio-focus), [Apple audio category options](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions).
