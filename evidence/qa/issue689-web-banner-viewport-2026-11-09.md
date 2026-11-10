# Issue 689: Web maintenance banner viewport

- RED: the browser fixture with unknown maintenance at 393×900 and 200% text
  placed the composer bottom at 983 px. The full accessibility run reported
  the same class of failure at multiple widths and for both conversation types.
- PASS: after the shell shares viewport height with notices, the responsive
  matrix passed all 21 cases again with the migrated typed WebSocket fixture.
  This is a dirty-source browser test, not the full final feature gate.
- VISUAL: inspected the focused 393×900 capture at source resolution. The
  warning wraps into three legible lines and the composer remains fully visible;
  its placeholder is truncated at enlarged text. The screenshot used a
  synthetic transport and is not evidence of a real server outage.
  The reviewed copy is `.out/issue689-visual/maintenance-unknown-200.png`
  (SHA-256 `318b1d2357f1f89bd93ee12c344d4a03b86721308add6a6a9799ca25ccbe9574`).
- NOT_RUN: full browser feature gate on a stable source revision, physical
  device acceptance, production cutover and load/security gates.
