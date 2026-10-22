# #518 — Windows publication follow-up

Windows Release 39759692409 failed before compiling the application. On the
actual Windows runner, two native-publisher tests converted a local path via
`new URL(...).pathname`; this produced `D:\C:\Users\...` and ENOENT. The third
negative test could pass because of this filesystem error instead of exercising
the intended remote-asset/tag rejection.

The fixture now passes `path.dirname(asset.path)` directly to the existing
publisher. The negative test also requires a remote tag read, so a pre-network
filesystem failure cannot count as its successful rejection. The same shared
publisher suite now runs in ordinary Windows CI before the long Flutter tests,
as well as in the protected release workflow. Publisher implementation,
source/tag validation, signatures and immutable asset checks are unchanged.

Local publisher regression: PASS, 17 tests. Actual Windows RED is retained in
the failed job above; the updated Windows CI and release provide native GREEN.

The unpublished windows-v1.0.45 tag is preserved at its original source. It is
not moved or reused for different bytes. Windows receives a new canonical
1.0.46 (81), release order 60. Shared Flutter version/identity defaults advance
together to preserve their existing consistency guard. This is release metadata
and publisher-test maintenance; #518 application behavior is unchanged.

The already delivered Web/macOS and signed iOS 1.0.45 (80), and Android's frozen
1.0.45 publication, keep their exact 9c221897 source identities. The portal must
show the version actually published per platform, rather than claim that an
advanced source contract implies every platform has shipped that version.
Final public readbacks are recorded on #518 before closure. Physical media
gates #62/#132/#303 remain NOT_RUN.
