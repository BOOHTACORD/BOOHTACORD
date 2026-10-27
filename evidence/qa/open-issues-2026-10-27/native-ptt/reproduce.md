# Physical Android PTT release and cancellation

Actual target: Samsung SM-A576B, Android16/API36, signed1.0.45+2080.
The fresh installed APK hash matches source9c221897; the evidence worktree HEAD
is a separate identity. No new APK, clearing app data or extracting phone cookies.

Preconditions: original owned empty DM is selected; voice is already in the
authorized SHARE_TEST with three actual participants. Original mode is VAD,
unmuted, RECORD_AUDIO granted with the recorded flags and microphone FGS80.
The PC reader uses an existing private controlled MEMBER session and matches
the exact phone account privately; it never logs the account/room/DM ID or name.

Helpers are retained as ../runner-source/*.txt. Copy them to their named
.out/qa-goal/ files; private fixtures and Playwright dependencies remain local.
Read native_ptt_peer.mjs before using the existing local session/peer mapping.

1. Read the actual phone state and original PC roster. Use the observed native
   navigation → account settings → audio settings controls. The initial helper
   v1 dispatched audio-open successfully, but subsequent UIAutomator reads did
   not return XML. Repeating the mutation is unsafe; reobserve the same screen.
2. Inspect an actual source-sized screenshot. Here audio settings was present.
   Scroll its content once to reveal the activation selector; original VAD was
   visibly selected. The one PTT tap used observed point750,1295 on1080×2340.
   Reobserve and adjust for a different viewport/scroll; never replay coordinates
   blindly. Devices, gain, noise processing and sliders were not changed.
3. Confirm actual native PTT selected and independent phone microphone_muted=true.
   Run `node .out/qa-goal/native_ptt_run.mjs`. The script drives real Android
   input DOWN and UP, UP outside, CANCEL, then HOME. Each held state must first
   become unmuted; each completion must become muted, with membership preserved.
4. The HOME case samples background after1200ms and verifies foreground resume
   does not unmute without another press. It does not prove long background,
   lock screen, an incoming phone call or TalkBack behavior.
5. The finally block selects the observed VAD option, verifies original unmuted
   roster, mic FGS80 and exact permission flags. Inspect the actual restored
   selector crop. Use Android Back to return to the owned DM and run
   `python -X utf8 .out/qa-goal/ptt_candidate_probe.py` to confirm APK hash,
   header match privately, empty composer and connected mic. This was done.

The Node→Python pipe used Windows default stdout encoding; copied resumed labels
were corrupt. Assertions used booleans only. result.json omits those copied labels
and links the original native UTF8 ui-resume.json. No case was rerun to repair text.
Future reproductions may set PYTHONUTF8=1 for the helper process; retain that change
as run metadata. Both UI-helper versions used in this run are retained.

Visual review at source resolution: held control has purple tint, released
control returns gray; restored VAD is selected purple and PTT is inactive. The
150×150 and897×132 crops contain static controls only. No new golden is accepted.

PC evidence is the actual authorized server roster, not a receiver SDK/PCM probe.
No audio was recorded and no human audibility claim is made. Immediate service
snapshots are asynchronous: FGS may lag a press/release. Only the settled muted
resume/no-FGS and final restored mic80 are established; transient service samples
are retained as observed. UI-label absence under a popup is not a disconnect.
