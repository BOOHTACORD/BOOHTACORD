# Offline speech fixture processing

Use only an authorized, locally obtained mono 48 kHz float32le fixture. Store
audio outside version control. The caller must supply its known SHA-256 and a
specific model directory plus matching lock file, as with the synthetic harness.
For example:

```
node tools/audio/speech_fixture/run.mjs --input <fixture.f32le> --sha256 <sha256> --output <new-output.f32le> --asset-dir <directory> --lock <lock.json>
```

The runner pads partial frames and appends 120 ms of silence to preserve the
model's tail. It refuses to overwrite an existing output, checks finite samples,
and reports hashes instead of audio or transcript content. The output remains
48 kHz mono float32le and may contain algorithmic delay. It makes no quality,
privacy, real-time, browser, native-client or listening-acceptance claim.
