# Issue 687: browser AEC/AGC capture settings

With repository head `7ed3c65e1c2dd15acf45489b6a5054c3616f6fbe`, a standalone
probe on the Windows host used headless Chromium, Edge and Firefox to open the
default real audio input four times, requesting all combinations of
`echoCancellation` and `autoGainControl` with `noiseSuppression: false`.
All three browsers reported the requested two boolean settings and disabled
noise suppression through `MediaStreamTrack.getSettings()` in all four fresh
captures. Each track was stopped immediately. No PCM, device labels or IDs
were retained, and no remote server or live conversation was used.

Chromium initially returned `NotSupportedError` without the automated
permission UI flag; using `--use-fake-ui-for-media-stream` allowed capture.
No fake media device flag was used. Firefox used the test-profile preference
that suppresses its permission prompt. This is a browser capture-settings
observation, not proof of effective AEC, actual gain control, acoustic quality,
processing order, model integration, Windows native behavior or echo rejection.
Those checks remain NOT_RUN. No release or deployment was performed.
