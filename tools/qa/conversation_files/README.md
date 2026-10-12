# Conversation files runtime acceptance (#254)

Run from the repository root on this configured local QA host, after building the Web client for the loopback origin:

```sh
VITE_PUBLIC_ORIGIN=https://localhost:4810 npm --prefix clients/web run build
python3 -m tools.qa.conversation_files.run
```

The runner reuses the local feature stack and Docker context `colima-boohtacord-qa`. It starts an owned PostgreSQL/API/LiveKit/Tempo/Caddy deployment for each width (1440 and 393 CSS px). The real production Vue bundle runs in Chromium against the real Go API; requests are not mocked. Three isolated browser contexts have MEMBER, MEMBER and ADMIN roles.

Six synthetic 70-byte PNG files are uploaded through the actual attachment inputs and sent through the actual composer. Fifty body-only synthetic rows per conversation put older files beyond the initial history cursor; attachment rows and objects are never seeded. Checks cover TEXT/DM metadata, cursor and origin navigation, live deletion on an older page, conversation isolation, close/reopen/refresh, and protected preview/download requests for both participants, a third administrator, an anonymous client and deleted objects.

Only role labels, HTTP status codes, synthetic file metadata and counts are reported. Header text is checked against its padded cell bounds after the Inter medium font and two animation frames are ready. Screenshots crop the files panel to exclude message bodies, account names and conversation identifiers. Private credentials stay in a temporary mode-0600 input. Owned services and the temporary directory are removed in `finally`; foreign services are never replaced. Reports and cropped screenshots are in `.out/qa254-20261012/`; inspect them before publishing evidence. Do not stage generated images or credentials.

Optional `QA_WIDTHS=393` selects only the registered mobile width for diagnosis. Browser viewport acceptance does not establish native Android/iOS or physical-device acceptance. This runner targets the configured local host rather than a portable CI environment.
