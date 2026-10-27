# Production native resume — 2026-10-28 Moscow

The user requested the production URL. Three scoped DM facets pass; the overall QA goal stays IN_PROGRESS. See summary.json for explicit results, exact candidate hashes, commands in cases.json, retained attempts and limits.

1. Start only with the existing approved production phone session, an empty owned QA DM, closed navigation, and privately provisioned peer B. Never extract a human session or put credentials in a command/output.
2. From local-qa-stack worktree run the retained paired_dm.mjs runner: native send and actual Chrome peer rendering. Its original overall failure is retained; only its outbound facet passes.
3. Run refresh_receive.mjs: send one owned fixture, invoke observed native Actions → Refresh history, scroll the actual ascending history viewport. This tests HTTP history, not realtime.
4. Invoke observed Retry only if visible. Run anchor_receive.mjs and then live_receive.mjs with the corrected observed Chrome Send-message label. The final run sends two fresh UI messages without native refresh, inspects actual native nodes and scrolls until the entire body-height bound is visible. It does not prove automatic scrolling or a latency percentile.
5. Finally delete only owned generated fixtures and verify native absence/empty composer. Preserve any active voice/media; no application restart was performed. Normal TLS validation remained enabled; production received no faults or load.

The first anchor attempt had a recovery banner: its original FAIL is not promoted to a product regression. The successful second anchor initially exposed only5px of its body; the separate final run requires>=54px. All available raw JSON attempts are retained, including the pre-send selector timeout. Final runner bytes were hashed before execution; canonical LF public copies are bound separately. Earlier runner variants were not all hash-attested before execution.

No new product defect was confirmed. Network path and WebSocket failure cause remain UNKNOWN. Phone source072426d6 and final deployed Web8a2cda38 are separate candidates; API source is UNKNOWN. No screenshot/body/identity/session material is published. Main local QA remains running; separate native HTTPS preparation is stopped, and isolated native fault acceptance still needs a trusted QA origin. Audibility remains NOT_RUN.
