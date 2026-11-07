# Historical welcome author: full Windows application

Product source: `156f76defba0ef0d5fa2823235a1c2b815678a9f` (PR #677).
Target: `clients/flutter/integration_test/welcome_author_full_qa_test.dart`.
Owned isolated PostgreSQL/API stack with disposable accounts and a newly created text channel.
Windows debug runner: PASS; `WELCOME_FULL_WORKSPACE_PASS uncached_author=true`.
The test registers a peer after configuring the welcome channel, opens the real workspace history, removes the peer from the local member directory and verifies its resolved name in the welcome row.
Initial attempts: local Firebase SDK extraction failed before runtime; restored from an existing working local SDK. The first runtime attempt failed because the fresh fixture had no text channel; the target now creates its own channel before registration.
No screenshot was captured. Full screenshot review and iOS runtime remain NOT_RUN; this result does not close visual, media, release or deployment gates.
