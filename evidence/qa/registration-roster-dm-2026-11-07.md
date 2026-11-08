# Registration, member discovery and direct messages — 2026-11-07

Candidate product source: `6bb3a5af9a299d72c24d4283711870a3ddadd238` (PR #674). Later commits in the PR update acceptance documentation only.

- PASS: isolated real Web, API and database: registration with 11 characters is rejected, 12 is accepted; a newly registered member appears in the open roster without reload and the count updates. Screenshots inspected at source resolution.
- PASS: physical Samsung SM-A576B with candidate Flutter app and isolated API: 11-character registration is rejected; a newly registered member appears live; tapping the author's chat name opens the profile and the Message action opens the intended direct conversation. Password error and profile screenshots inspected at source resolution. Long synthetic profile names can wrap.
- PASS: focused Web and Flutter unit/widget regressions for presence, page races, password policy and name-to-DM including voice rows/cards. Flutter static analysis and Web production build passed.
- NOT_REPRODUCED: reported registration with fewer than 12 characters on current candidate/server baseline. Origin and behavior of deployed versions remain unverified. Existing account login with a short password remains allowed.
- NOT_RUN: candidate Windows UI against real API and voice-name-to-DM on a real connected voice call; iOS runtime. A Flutter widget test is not a native acceptance result.
- PENDING: complete project-owned real-stack feature gate, screenshot review and exact-head CI; deployment and release are not claimed.
