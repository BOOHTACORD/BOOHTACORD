# Physical native PNG acceptance

Use the same signed candidate and actual owned test-peer DM on the phone, with
an empty composer. Preserve the initial microphone/voice state. The current
private fixture/session inputs, ADB, Pillow with ImageCms and installed headed
Chrome are required. Copy final helper sources from `runner-source/*.txt` to
their matching `.out/qa-goal/` filenames; common permission/fixture helpers are
retained in the parent packet. Never publish the private inputs or PNG bytes.

Start from a fresh packet: prior fixture config and peer command file must not
be reused blindly. The helper refuses to overwrite an existing fixture config.
Archive that exact config only after the prior message deletion and phone file
absence are verified. Do not delete the whole `.out` directory. Initialize the
peer command file with sequence0 before launching a new peer process.

```powershell
python -c "import json;from pathlib import Path;Path('.out/qa-goal/native-attachment-peer-command.json').write_text(json.dumps({'sequence':0,'action':'idle'}),encoding='utf-8')"
```

Actual CLI sequence used for selection on this phone:

```powershell
python .out/qa-goal/android_attachment_picker.py prepare
python .out/qa-goal/android_attachment_picker.py open
python .out/qa-goal/android_attachment_picker.py roots
python .out/qa-goal/android_attachment_picker.py downloads
```

Inspect the safe picker report; it must find exactly one owned fixture. No
personal file listing is retained. In a separate terminal start the real peer:

```powershell
node .out/qa-goal/native_attachment_peer.mjs
```

Wait for its receipt status READY, confirming the actual process remains live.
Continue in the first terminal:

```powershell
python .out/qa-goal/android_attachment_picker.py select
python .out/qa-goal/android_attachment_actions.py send
python -c "import json;from pathlib import Path;Path('.out/qa-goal/native-attachment-peer-command.json').write_text(json.dumps({'sequence':1,'action':'receive'}),encoding='utf-8')"
```

Wait for completed_sequence1/PASS_SCOPED. Then:

```powershell
python .out/qa-goal/android_attachment_actions.py view
python -c "import json;from pathlib import Path;Path('.out/qa-goal/native-attachment-peer-command.json').write_text(json.dumps({'sequence':2,'action':'view-acl'}),encoding='utf-8')"
```

The native probe must honor the screenshot's embedded ICC profile, detect all
four fixture quadrants, and reject the wrong-order probe counterexample. This
is a synthetic raster check, not a human visual review or an approved golden.
Wait for peer sequence2/PASS_SCOPED, including actual browser image decode.

```powershell
python .out/qa-goal/android_attachment_actions.py close-view
python .out/qa-goal/android_attachment_actions.py delete-menu
python .out/qa-goal/android_attachment_actions.py delete
```

Inspect the confirmation controls before the second Delete. Delete only the
message whose observed ancestor contains the owned fixture preview.

```powershell
python .out/qa-goal/android_attachment_actions.py delete
python -c "import json;from pathlib import Path;Path('.out/qa-goal/native-attachment-peer-command.json').write_text(json.dumps({'sequence':3,'action':'deleted'}),encoding='utf-8')"
```

Wait for peer sequence3/PASS_SCOPED, tombstone and denied original access. Then:

```powershell
python .out/qa-goal/android_attachment_picker.py cleanup-file
python -c "import json;from pathlib import Path;Path('.out/qa-goal/native-attachment-peer-command.json').write_text(json.dumps({'sequence':4,'action':'stop'}),encoding='utf-8')"
python .out/qa-goal/android_controls.py inspect
```

Confirm the peer process completed, the owned file is absent, composer is empty,
original voice/mic/font state and real paired roster are preserved. If an action
fails, inspect the same current process/device state and restore explicitly;
never restart a live peer merely because observation timed out. No current
packet acceptance is claimed for JPEG/GIF, clipboard, native save/download,
third ADMIN, post-delete preview, audibility or media capacity.
