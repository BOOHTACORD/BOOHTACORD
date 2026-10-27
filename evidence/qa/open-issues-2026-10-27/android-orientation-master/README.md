# Android current-master landscape/IME reproduction

**FAIL: existing bug #582 reproduces on signed QA candidate 1.0.47/2082**,
source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.
The installed APK hash was checked before the physical run.

| Protection | Command | Platform | Mandatory when | Result |
| --- | --- | --- | --- | --- |
| Send and Leave remain distinct while Gboard is open in landscape | `python -X utf8 .out/qa-goal/android_orientation_run.py`, then `orientation_control_crops.py` and `orientation_master_geometry.py` | Physical SM-A576B Android16/API36, real Gboard and native voice | Before current Android orientation/IME acceptance in QA62/303 and regression adequacy in QA302 | `summary.json`, `invariant-result.json`, original run JSON and four source-resolution masked crops |
| Draft, voice and original settings survive rotation and cleanup | Same physical protocol; complete the baseline/focus/draft prerequisites retained in `cases.json` | Same phone plus actual independent server roster read on PC | Every run of this physical protocol | `android-orientation-result.json` and its final peer/restoration fields |

Measured Send bounds `[2183,264,2318,399]` and Leave bounds
`[2171,318,2306,453]` intersect by **123 x 81 = 9963 px**.
Both controls are enabled. The red Leave button visually covers Send's icon.
The recorded-observation invariant checker exits with code 1. It reads the actual native
protocol's JSON; it does not itself produce a new device observation.

Portrait and landscape after Back hides the IME show Send clearly separated.
The owned 20-character draft, three participants in voice, microphone permission,
original rotation settings and empty composer were preserved/restored.
No overlap click, message send, acoustic result or accidental disconnect is claimed.
Old evidence on Android 1.0.45 remains unchanged. This is one fresh run on 1.0.47.
