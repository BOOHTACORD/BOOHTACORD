# Issue #689 R1: late workspace continuations, partial

- Two focused tests reproduced a late notification and a follow-up edited
  history refresh after the original Web socket had been replaced.
- Socket-incarnation checks suppress those continuations after disconnect.
  Existing account-switch and notification behaviour remain covered.
- Nineteen focused tests passed locally after the initial fix. Real network
  race, current-source visual/device acceptance and cancellation of requests
  already mutating stores remain separate and are not claimed here.
