# Issue582: healthy/recovering dense voice row

Packet small_direct; route workspace_screen/build/editing_shell, with the
RealtimeRecoveryStatus visibility edge. Backlog FV2-003/FV2-006, existing
workspace/realtime/native-layout dependencies and checks preserved.

Physical signed606/de4c proved Send/Leave disjoint in all5states, with native
Gboard,18-character draft and SHARE_TEST membership preserved. Source-sized
review also found a visual failure: an invisible recovery widget retained half
the row, squeezing the live6ms voice status into3lines and truncating the room.
This packet fixes that observed followup before closing the device gate.

1. Add a focused production WorkspaceScreen RED for measured RTT and realistic
   Samsung landscape cutout/IME metrics, across healthy/recovering/initial chat.
2. Share the existing recovery visibility predicate with shell composition;
   allocate no recovery slot when hidden and sufficient voice width when shown.
3. Preserve voice controls/callbacks, retry guards, drafts/selection, native-only
   viewport threshold and ordinary portrait/desktop behavior.
4. Run nearest workspace/realtime tests and targeted analysis; verify platform
   parity and register the scenario. Keep finite167CI capture names unchanged.
5. Inspect custom source-sized component captures and retain source/log hashes.
6. Handoff source to release_closure for PR/CI/merge/signed candidate; root owns
   physical positive rerun plus actual Send/PC receipt and owned cleanup.

Target100/hard120lines per changed Dart file; target8/hard16 production/tests
per leaf. Source changes limited to the2exact composition/presentation edges.
No controller/retry/media/contract/backlog changes; no43consolidations.
Stop: reviewed local packet handed off. Physical and unavailable platform gates
remain pending until actual corrected candidate evidence, never widget-only.
