# Issue #689 R1: socket and roster incarnations

- Base source: `02dd970d62ca1a349b50cb9a3df363cbc181a3a9`; this record
  belongs to the commit containing the changes, not to a deployed build.
- Before the change, a delayed protected recovery kept the new socket's roster
  event behind the old queue. The added Web regression failed with no new
  snapshot delivered. The Go regression failed because the next account
  incarnation reused the prior generation while restarting its revision.
- After the change, disconnect invalidates queued socket delivery and its batch
  bookkeeping while preserving the last applied durable cursor. A new account
  coordinator incarnation receives a new UUID generation; simultaneous sessions
  share the same generation while their account state remains active.
- Local Web source checks: 63 tests passed, including the store/roster path,
  delayed recovery, durable replay and prior overflow regressions. Coordinator
  Go tests passed; the coordinator race test also passed in Linux with Go 1.26.4
  before the final additional stale-state assertion was added. The first Windows
  race attempt could not start because CGO was disabled. Parity registry
  validation and its policy tests passed.
- This source-level packet does not prove cancellation of every already-running
  protected REST mutation or establish network, device, production or full R1
  acceptance. Real-stack Web, screenshot review, Flutter/native, load and
  all remaining #689 criteria remain NOT_RUN until separately verified.
