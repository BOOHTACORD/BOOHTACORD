# Physical Android orientation/IME counterexample

Actual target: Samsung SM-A576B, Android16/API36, signed1.0.45+2080,
source9c221897,1080×2340 portrait /2340×1080 landscape, density450, font1.0.
Gboard18.5.4.993608717-release-arm64-v8a. Fresh installed APK hash is in candidate.json.
This is the released installed APK, not a new build from the evidence branch.

Preconditions: own empty synthetic-peer DM, active SHARE_TEST voice connection
with3 participants and unmuted phone, RECORD_AUDIO granted, mic FGS80. Original
system settings are accelerometer_rotation1/user_rotation0. Do not use another
person's conversation or clear an unknown draft. Private fixture/session inputs
remain local and are never included in evidence.

1. Select/focus the observed empty native composer. Open the real Gboard window.
   Insert one20-character private synthetic marker using Android input text;
   this is not a human/Gboard typing acceptance. Do not send it.
2. Run android_orientation_run.py. It temporarily locks sensor rotation and sets
   user_rotation1, causing a real Android display/window configuration change.
   This does not test gravity/accelerometer response or simulated Flutter scale.
3. Observe landscape with Gboard open: native Send bounds2183,264–2318,399 and
   voice Leave bounds2171,318–2306,453 overlap by123×81px. The red Leave control
   visibly covers Send. The Send center is geometrically inside Leave; the
   overlapping area was not clicked, so no accidental disconnect is claimed.
4. Actual Android Back hides Gboard. Send becomes visibly exposed again and
   the unsent marker remains. Rotate back to portrait: the marker remains.
5. The finally block restores original rotation settings and deletes only the
   exact owned marker, hides the keyboard and verifies empty composer, same
   permission flags, mic FGS80 and actual independent PC roster3/unmuted.

The complete protocol was repeated twice. run1/result.json and run2/result.json
retain the original controller REVIEW_REQUIRED disposition. overlap-analysis.json
and summary.json add the visual/manual FAIL and separate passing retention scope.
The same masked landscape-with-IME control crop is byte-identical across runs.
Each run restored settings and the owned draft; no app install/logout/server fault.

Helpers are retained under ../runner-source/*.txt. Copy to their named .out/qa-goal
paths. Prepare private-orientation-fixture.json with the owned peer and a random
ASCII text marker. Validate the initial empty view before the following commands:

```
python -X utf8 .out/qa-goal/android_orientation_state.py snapshot before
python -X utf8 .out/qa-goal/android_orientation_state.py focus portrait-ime
python -X utf8 .out/qa-goal/android_orientation_state.py type portrait-draft
python -X utf8 .out/qa-goal/android_orientation_run.py
python -X utf8 .out/qa-goal/orientation_control_crops.py
python -X utf8 .out/qa-goal/orientation_candidate.py
```

Preserve run1 files before a repeated run; these helpers use fixed local output
names. The actual UI screenshots remain private. Published composer/dock crops
exclude identity/history, mask the draft and retain the observed Send rectangle;
they are source-sized, with no resampling/new golden. IME flags and actual package
identity accompany each snapshot. No full keyboard/personal suggestion image.

Unknown: actual Send/hit-test outcome, iOS, opposite landscape, other IMEs,
selection range, exact focus restoration, physical sensor rotation, acoustic
continuity or a newly packaged master build. No gate covering them is accepted.
