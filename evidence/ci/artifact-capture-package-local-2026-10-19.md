# #387 / CICD-18 — local lossless capture package

Status: **LOCAL_CONVERTER_PASS; hosted workflow, retention and release acceptance
NOT_RUN**. The prototype is not wired into CI and #387 remains open.

The input consists of three real browser artifacts from PR #431, run39242729846,
checkout `5ece75ffe4e1293ab976a76dbcfb7abe47d2d7c0` / headf98d6f56. ZIP sizes,
SHA256 and bounded inventories were checked before processing. The inventory has
942 PNGs and138 JSON files. It found no trace/log/private-configuration paths,
known sensitive fields or JWT-shaped values; this is **not a universal privacy
PASS**. Owned-fixture/source dataflow review and publication policy remain required.

| Input artifact | Logical files | Unique payloads | GitHub input ZIP bytes | Local Python ZIP bytes |
| --- | ---: | ---: | ---: | ---: |
| 12182521674 / voice | 410 | 397 | 18493322 | 17842200 |
| 12182079286 / shell | 358 | 341 | 14369722 | 13571819 |
| 12181079626 / conversations | 312 | 266 | 10968399 | 10138531 |

All1080 logical files were restored and compared byte-for-byte through SHA256.
The76 exact duplicate payloads account for2506218 uncompressed bytes. The local
ZIP codec observation is preliminary: it is not an actual after-policy GitHub
upload, runner/billing measurement or trusted new producer receipt. Prototype
identity uses the original input producer as an explicit verification fixture;
there is no new hosted execution claim.

The package keeps one PNG/JSON blob per exact content hash, with every original
logical path in an index. `integrity: PASS` proves storage integrity only; it
cannot replace a test or release verdict. A failed QA report remains FAIL after
roundtrip. The verifier requires exact repository/source/run/attempt/namespace/
component/profile/platform identity and rejects unknown fields, missing/extra/
changed payloads, duplicate JSON keys, unsafe paths and source substitution.

Focused tests preceded implementation. Additional red stages exposed numeric/
structured secret values, linked parent directories, ambiguous Windows device/
case/Unicode aliases and file/directory conflicts. These are rejected before
copying. Known auth-field/JWT guards supplement bounded PNG-header/JSON checks;
they do not establish PII absence in pixels or arbitrary text. No personal desktop
capture or arbitrary input directory is authorized by the package format.

The19 focused artifact-policy tests pass. The full local Python suite passes
**790 tests in 41.552 seconds**. Actual runtime context validation, allowlisted
capture collection, failure-diagnostic handling, workflow policy integration,
automatic hosted artifact download verification and matched PR/master/tag/QA
measurements remain pending. Existing30-day release/package/acceptance retention,
legacy controls and native release asset formats remain unchanged.
