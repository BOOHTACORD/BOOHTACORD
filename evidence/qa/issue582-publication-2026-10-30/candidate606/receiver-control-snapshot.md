# Production Web receiver control record

Platform: Windows 11 host, WSL2 Ubuntu, NEW Linux headed Chromium on owned Xvfb.
This does not prove Windows native Chrome, native Windows client, audibility, or media quality.
Current browser/context is alive; DO NOT rerun launch or login for final611.
All commands below belong only to this owned receiver. No Windows GUI actions occurred.

## Exact launch used

From PowerShell:

```powershell
wsl.exe -d Ubuntu --exec /usr/bin/xvfb-run -a --server-num=143 '--server-args=-screen 0 1600x1200x24' /var/tmp/boohtacord-qa-tools-5925815800ab2026/node-v24.18.0-linux-x64/bin/node /mnt/c/Users/egkur/.codex/worktrees/android-landscape-send/BOOHTACORD/.out/issue582/pc-receiver/receiver.mjs
```

The script reads the approved private B fixture locally and makes one normal API login with exact Origin.
It verifies secure HttpOnly cookie, own MEMBER binding, and existing phone pair before opening full UI.
TLS is default; no HTTPS bypass, reused profile, reused cookies, account creation, DM creation, or browser sends.
Windows exec session 38040; owned Linux Node PID 862. PID must be reverified before termination.

## Exact extension installation used in the same live context

```powershell
wsl.exe -d Ubuntu --exec /bin/ps -p 862 -o pid=,args=
wsl.exe -d Ubuntu --exec /bin/kill -USR1 862
wsl.exe -d Ubuntu --exec /var/tmp/boohtacord-qa-tools-5925815800ab2026/node-v24.18.0-linux-x64/bin/node /mnt/c/Users/egkur/.codex/worktrees/android-landscape-send/BOOHTACORD/.out/issue582/pc-receiver/install_extra.mjs
```

The Node inspector was temporary, loopback only, and targeted this newly owned QA Node process.
It injected only this subtree's QA operations into its existing lexical state.
No existing Windows Chrome, profile, or browser CDP endpoint was used.
Installation returned installed=true, loginCount=1, ownedPairVerified=true. The temporary inspector was closed.
Two initial extension-install attempts failed before injection due to a missing dynamic-import callback.
The corrected injector uses the paused owned module's existing imports; it did not relaunch or log in.

## Controls for final611

Root writes `trigger.private.json` privately with the exact owned fixture marker. Never print its contents.
Set this variable only to the owned directory:

```powershell
$receiverRoot = 'C:\Users\egkur\.codex\worktrees\android-landscape-send\BOOHTACORD\.out\issue582\pc-receiver'
```

Arm before Send, verify `extra-result.json` reports `armed=true` and `atLatest=true`:

```powershell
[System.IO.File]::WriteAllText((Join-Path $receiverRoot 'extra-command.private.json'), '{"id":"arm-run611","op":"arm","run":"run611"}', [System.Text.UTF8Encoding]::new($false))
Get-Content -LiteralPath (Join-Path $receiverRoot 'extra-result.json') -Raw -Encoding UTF8
```

After the phone joins SHARE_TEST and before Send:

```powershell
[System.IO.File]::WriteAllText((Join-Path $receiverRoot 'extra-command.private.json'), '{"id":"run611-before","op":"roster","phase":"before"}', [System.Text.UTF8Encoding]::new($false))
```

Copy the sanitized result to `roster-run611-before.json` after its matching id appears.
The armed watcher automatically captures first visible exact fixture text and verifies the API author binding.
Read `received-run611.json`; exact message and author IDs are only in `private/observed-run611.private.json`.
Inspect its PNG at original resolution. Do not navigate or refresh after Send.

After Send, before phone leaves voice:

```powershell
[System.IO.File]::WriteAllText((Join-Path $receiverRoot 'extra-command.private.json'), '{"id":"run611-after","op":"roster","phase":"after"}', [System.Text.UTF8Encoding]::new($false))
```

Copy the sanitized result to `roster-run611-after.json` after its matching id appears.
Only after root confirms exact native author deletion:

```powershell
[System.IO.File]::WriteAllText((Join-Path $receiverRoot 'command.private.json'), '{"id":"run611-deleted","op":"verify-deleted"}', [System.Text.UTF8Encoding]::new($false))
```

Read `command-result.json` and retain the matching result as `deleted-run611.json`.
For strict attachments-array confirmation, target only verified PID 862, then run:

```powershell
wsl.exe -d Ubuntu --exec /bin/kill -USR1 862
wsl.exe -d Ubuntu --exec /var/tmp/boohtacord-qa-tools-5925815800ab2026/node-v24.18.0-linux-x64/bin/node /mnt/c/Users/egkur/.codex/worktrees/android-landscape-send/BOOHTACORD/.out/issue582/pc-receiver/inspect_tombstone.mjs
```

Only after root says done, request own-session logout and browser close:

```powershell
[System.IO.File]::WriteAllText((Join-Path $receiverRoot 'command.private.json'), '{"id":"shutdown","op":"shutdown"}', [System.Text.UTF8Encoding]::new($false))
```

Verify ownSessionRevoked=true and ownedBrowserClosed=true in `command-result.json` first.
The current live extension loop was injected before its exit condition was added to the saved source.
If the wrapper remains alive after successful logout/browser close, verify PID command line, then terminate only owned Node PID 862.
`xvfb-run` then removes its owned display/auth. Do not kill any other Chromium/Xvfb process or X0.

## Commands, mandatory conditions, and actual results

| Command / check | Platform | mandatory_when | Actual result |
|---|---|---|---|
| Node `--check` bootstrap/receiver/operations | WSL Node 24.18.0 | Before launch | PASS |
| Exact xvfb-run launch above | Linux headed Chromium / Windows host | Real Web receiver acceptance | PASS; one login204, secure HttpOnly, MEMBER, owned pair, full UI |
| arm run606 | Same browser/context | Before native Send | PASS; latest, fixture absent, continuous visible watch |
| GET `/api/v1/channels` + `/api/v1/voice/participants`, BEFORE run606 | Same B request context | Voice membership before Send | PASS200; exactly one phone-bound SHARE_TEST participant |
| Armed native Web exact-text watch | Same full production Web UI | Android Send becomes visible | PASS; exact fixture visible23:18:03.303Z; one API record; author=phone binding; original PNG reviewed by root |
| Same roster GETs, AFTER run606 | Same B context | Voice membership after Send | PASS200; phone present; same room/binding |
| verify-deleted + strict tombstone probe | Same B context and actual Web UI | After native author deletion | PASS; deleted, empty body, attachments[]; Web tombstone; marker absent; original PNG reviewed by root |
| final611 full rerun | Same held B context | Final signed candidate acceptance | PENDING |
| Public lease equality | Public roster contract | Only if contract exposes it | NOT_RUN; no lease field; no secure-storage extraction |
| Native Windows Chrome/client | Windows GUI runtime | A Windows-native claim | NOT_RUN |
| Audibility/media quality | Media observation/load evidence | Such a claim | NOT_RUN |
| Own logout/browser/process/display cleanup | Owned receiver only | Root says done | PENDING; same context retained for final611 |
