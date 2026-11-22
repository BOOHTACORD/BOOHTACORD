# Issue 790: Android update catalog

- Android release: `android-v1.0.59`, stable, build `95`, release order `74`.
- Source revision: `9cc96e33612f4560b183d3e53e3ce1484bec29cf`.
- [Android release workflow](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/44957828457): PASS. The published manifest reports a clean source and signed packages for arm64-v8a, armeabi-v7a and x86_64; its SHA-256 is `fa72bb5e14849f144ccd4d2f94664f9277531ff6b5d668ae522f093b408d9f25`.
- This change updates the three Android direct/stable selectors from release order 73 to 74 while retaining each architecture requirement. Other selectors are unchanged.
- Physical-device installation and in-place update acceptance: NOT_RUN. Publishing a catalog entry does not prove installed-client acceptance.
- Catalog deployment and live endpoint readback: NOT_RUN until the resulting exact-source deployment completes.
