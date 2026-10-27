# Physical Wi-Fi / cellular application handoff

Target: one USB-authorized Samsung SM-A576B, Android16/API36, signed1.0.45+2080,
source9c221897. candidate.json verifies the fresh installed APK hash. Clean repeat
uses headed Windows Chrome155.0.8059.85 and runtime Web source072426d6. No mocks.

Preconditions: own empty controlled-peer DM; SHARE_TEST voice already connected
with3 participants and unmuted phone/mic FGS80; original Wi-Fi1/mobile_data1;
current default validated WIFI; both telephony call states0. The reader privately
matches the phone account and existing DM. Never print identities, cookies,
addresses, SSID, phone numbers or the private body fixture.

Copy retained helpers from ../runner-source/*.txt to their named .out/qa-goal
paths. Existing controlled private accounts/sessions and Playwright dependencies
are required. Run the current, corrected controller:

```
node .out/qa-goal/native_connectivity_run.mjs
```

It opens the actual controlled PC DM, captures receiver browser/source, checks
current Android/network/call state and arms an independent45s Wi-Fi-enable guard.
Only the phone's Wi-Fi is disabled; router/VPN/mobile-data/operator settings are
unchanged. The controller samples actual current network agents by exact default
network identity, publishing transport/capability booleans only.

When CELLULAR has INTERNET capability, normal native UI enters a private random
20-character marker and clicks the observed Send. A geometry guard rejects the
known landscape Send/Leave overlap. Independent PC API checks the phone author,
and the actual browser must render the marker. Before Send and after PC receipt,
default transport must be CELLULAR with Wi-Fi0. OS VALIDATED is recorded but does
not replace that app-level proof. If no mobile INTERNET transport appears, keep
the result partial and restore Wi-Fi; do not infer a product defect.

Finally the controller enables Wi-Fi, releases/waits for the guard, waits for
validated WIFI, opens only the fixture-scoped native action menu, confirms Delete,
polls the actual server for a tombstone within6s, and requires the PC text to
disappear. It verifies local fixture count0/empty composer, exact permission,
mic FGS80, native connected status and independent roster3/unmuted. The6s budget
is a harness wait, not a production latency SLO. The timeout guard was not fired.

Retained chronology matters:

- initial-partial-run.json used v1 helpers and required OS VALIDATED. Mobile
  transport appeared but was not yet validated, so no fixture was sent. Wi-Fi
  was restored. This is not an application FAIL.
- handoff-original-controller-result.json used v2. Actual cellular delivery and
  PC rendering passed; cleanup stopped because a popup hid the DM header.
- cleanup-first-attempt.json rechecked the exact server author and selected
  fixture before two Delete/confirm actions. An immediate tombstone read was
  false; the controller stopped. No assumption of app failure is made.
- cleanup-and-restoration.json is the later independent read-only observation:
  exactly one recent owned message was deleted, with no local fixture; original
  state restored. Delete was not repeated. Exact deletion latency was unmeasured.
- clean-repeat.json used the current corrected UI guard and bounded polling.
  It completed the whole controller with PASS, including server/PC/native cleanup
  and exact runtime receiver source. No manual recovery was needed.

Version mapping is in summary.json. v1/v2/helper failures are retained rather than
rewritten; historical repair scripts are specific to their recorded pending
fixture and must not be blindly replayed in another conversation/state.

Radio-off intervals:12.852s,12.455s,11.610s. All guards were released, exit0;
post-run process inspection found0 guard processes. The final source-sized
1080×307 native voice-dock crop was inspected and excludes conversation/identity.

No audibility, packet/frame continuity, explicit SDK reconnect event, long outage,
background/lock, iOS/Pixel/macOS, session revoke or account-switch acceptance.
Brief intermediate states could be missed. Full QA/media gates remain open.
