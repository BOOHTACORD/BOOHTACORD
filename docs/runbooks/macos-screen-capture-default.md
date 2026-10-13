# macOS ScreenCaptureKit default (#334)

The ordinary Flutter client requests `screen_capture_kit` for both selected
windows and displays. On macOS 13+ the existing native adapter performs capture.
On older macOS the native version check keeps the previous WebRTC route with
the selected source. An unavailable selected window still fails; it is never
replaced with a full display. Codec, profile/FPS and audio options are unchanged.

After resolving the locked dependencies, build from `clients/flutter`:

```sh
flutter build macos --release --no-pub
```

For a manual return to the previous routes on a new capture start:

```sh
flutter build macos --release --no-pub \
  --dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=baseline
```

This override restores the existing baseline: legacy window capture and the
existing ScreenCaptureKit display path on supported macOS. It does not force
displays onto a different capturer. A running share must be stopped before
starting with a different build.

The existing local native capture diagnostics snapshot reports `engine` as
`screen_capture_kit` or `rtc_desktop_capturer`, and `sourceClass` as `window`
or `display`. These fields do not contain screen content or window identifiers.
No new telemetry is needed.

Basic acceptance uses one Mac and a Web viewer, including on that same Mac:
share a moving window at 1080p60 for 30–60 seconds, repeat for a display, then
stop/start once while retaining voice. Record the actual engine and whether
screen audio is present. Exact 60 FPS, prolonged/load tests and a device matrix
are outside #334. Missing runtime checks remain `NOT_RUN`.
