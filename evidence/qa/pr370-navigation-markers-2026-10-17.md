# PR #370: selected navigation marker acceptance

2026-10-17, Europe/Istanbul. Backlog leaf DW-005; dependencies T-050/T-020/T-041/T-022/DW-003/DW-004 reviewed. Base master `332ef84ae536da3e811a5cdd0e98b1ca53564f68` includes the accepted clipboard fix #369. Clean tested integration source `0b91d37c72d5c7c920a55db267447e26cca2f526`; the adjacent JSON records source/screenshot/log hashes and stage results.

Three CSS declarations use `--gc-accent-text` for selected-tab underlines and selected channel/DM left markers instead of `currentColor`. Text color, layout, semantics, event handling, ACL and the foundation's separate keyboard focus outline remain unchanged. The original PR product/test implementation is retained; integration adds current master and this acceptance record.

## Results

- Baseline reproduction: restore only the three changed CSS files to current master in the clean owned worktree, retaining the new browser test. Two inventory cases pass; the focused regression fails as expected: actual marker `rgb(244, 245, 250)`, expected accent `rgb(172, 174, 255)`. All original CSS bytes are restored in `finally` before candidate acceptance.
- Candidate: 1571 unit tests and production build PASS. All 11 registered shell browser suites PASS, including 110 accessibility checks, 87 control-consistency cases and 27 navigation cases with actual 200% browser zoom.
- Full local Web shell runner: 15/15 stages PASS, including real Go/PostgreSQL/LiveKit/Tempo desktop1440 and touch393 lifecycle runs. Both end with actual browser lifecycle and Tempo confirmation, and owned resources removed.
- The old PR's occupied-port blocker is resolved for this run: ports4810/4812 were free; no existing tunnel or service was stopped.
- Ten selected images opened at original resolution: four Before, four After focused marker captures and two fresh actual authenticated-client captures. Their hashes/dimensions/observations are in JSON. Selected markers are lavender at desktop and mobile sizes; labels/counters remain readable and dock/footer remain separate. Before DM inventory is scrolled to the bottom and does not show its selected row; only its tab marker is claimed from that capture. The After focused case scrolls to the selected DM row and checks its computed color. Actual desktop sidebar and mobile drawer show the same accent selection. The lower mobile channel list remains in its existing scroll viewport.

The raw aggregate report stays REVIEW_REQUIRED for incidental images outside this marker-only review. No screenshot reference/baseline was approved. This Web CSS change does not establish native/mobile-hardware or media quality/capacity acceptance.

## Commands

Pinned Node24.18.0; dedicated child Docker configuration/context; existing local-feature Python environment. From `clients/web` for baseline reproduction, while only the three product CSS files are temporarily the master version:

```sh
node node_modules/@playwright/test/cli.js test -c tests/navigation_density/playwright.config.ts --grep 'selected navigation controls|inventory production navigation (390|1440)px' --output ../../.out/pr370/before
```

From the root after restoring the candidate CSS, using check.sh's underlying module to retain the pinned Node PATH:

```sh
python3 -m tools.qa.local_features.run --feature shell --platform web --base 332ef84ae536da3e811a5cdd0e98b1ca53564f68 --real-stack
```

Run: `.out/local-features/20261017-231817`. No requirement, backlog or wire-contract delta was introduced. CI checks on the exact published head are evaluated separately before merging and linked in PR metadata/final receipt. The previous master and original PR branch history are preserved.
