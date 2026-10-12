# Navigation preference browser acceptance (#251)

Run from the repository root on the configured local QA host:

```sh
python3 -m tools.qa.navigation_preferences.run
```

Reuses the existing local feature stack: disposable PostgreSQL, Go API, pinned LiveKit, Tempo and Caddy. Docker context is `colima-boohtacord-qa`. The two loopback HTTPS origins use the same synthetic guild/accounts/database, with a separate API Origin configuration for each port. No production endpoint is used. A private temporary input holds the generated password and is removed with the owned work directory.

Runs Chromium at 1440 and 393 CSS px. Checks account/origin separation, add/remove and reload, case-insensitive channel/category search, the connected voice dock after collapse (including an actual Leave click), and archive cleanup without additional topology changes. Own containers/network/image are removed in `finally`; foreign port usage fails instead of replacing it. The media connection is listener-only and does not establish audio quality or physical-device acceptance.

Reports and screenshots are in `.out/qa251-20261012/`. Inspect screenshots before publishing evidence or closing an issue. Generated media and credentials must not be staged. The runner currently targets this host setup and is not a portable CI entrypoint.
