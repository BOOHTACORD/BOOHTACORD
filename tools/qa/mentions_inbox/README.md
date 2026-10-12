# Personal mentions runtime acceptance (#264)

From the configured local QA host, build the production Web bundle for the owned loopback origin and run:

```sh
VITE_PUBLIC_ORIGIN=https://localhost:4810 npm --prefix clients/web run build
python3 -m tools.qa.mentions_inbox.run
```

Uses the existing local feature Stack, pinned PostgreSQL/API/SFU/Tempo/Caddy and Docker context `colima-boohtacord-qa`. Runs isolated Chromium contexts at 1440 and 393 CSS px against actual Go endpoints. Two MEMBER accounts and a third ADMIN use synthetic aliases. Real REST mutations create the principal mentions, edit/remove/delete them and rename the author. Fifty-five old synthetic SQL messages exercise cursor paging; their content is never recorded in evidence.

The scenario verifies metadata-only results, account/DM isolation, exact protected TEXT/DM history, keyboard activation and the existing picker composition guards. Adversarial SQL changes in the owned disposable database produce stale catalog/DM access after an inbox row is already displayed. This is a failure fixture, not a product operation for changing channel kind or DM participants. The actual API must deny former access, and the UI must refresh authoritative navigation before routing. An owned API stop/restart tests errors; held actual HTTP responses test loading and same-page logout/account switch. No successful HTTP response payload is fabricated.

Composition events are controlled browser events; OS-level IME/device acceptance is outside this Web scenario. Cropped captures include only the visible metadata panel and synthetic role aliases; no message bodies, account/DM IDs, credentials or attachment contents are captured. Generated images and results stay ignored in `.out/qa264-20261012/`; publish only sanitized results/hash receipts after visual inspection. Owned services, the temporary private input and work directory are removed in `finally`. Optional `QA_WIDTHS=393` repeats only the registered mobile width.
