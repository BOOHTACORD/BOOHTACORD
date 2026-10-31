# Additional cutover evidence — #401 / epic #382

Decision: **NO-GO**. These records add actual comparisons and native smoke;
they do not close the remaining release, installation, operator or owner gates.
Actual execution SHAs are preserved below and inside each original receipt.

Implementation master: `d7a88aa51a0e6d265436df0e24a437a252332c80`
([PR #489](https://github.com/BOOHTACORD/BOOHTACORD/pull/489)).
CI39400762908 passed all17selectedjobs with2expectedskips; required
118559128521/Actions15368 binds exacthead4d7ce86. Testedmergea115f31 and
final squash have tree24654ac35cbf6f6261a644355eca0c4836d83180.
Superseded configuration proposal487 was closed without merge; settings remain
unchanged. This source change includes tools/release and therefore invalidates
strict runtime-input equivalence to old producer88f42cf. Guards stay strict;
waiting producers are not treated as completed release evidence.

| Check | Actual source / run | Independently verified outcome | Limits |
| --- | --- | --- | --- |
| Web old/new | `688925dc36bfc3f8c65a590053e0f1e91651cf8d` / 39377129056 | Six original inputs plus comparison ZIP; replay against 22 actual jobs exactly matches; three samples per arm, original coverage preserved | Median critical 1287→514 seconds, runner minutes 21.45→25.466667; descriptive n=3, cost increased |
| Flutter old/new | `a946915037619d9d46a229c2ed60ba51a70a1ba7` / 39394548666 | Nine original inputs plus comparison ZIP; all 13 jobs successful, independent replay exactly matches; three prescribed samples per arm | Median critical 1097→570 seconds, runner minutes 18.283333→16.483333; no general CI SLO/flake-rate or device/media claim; large APK payloads not independently downloaded again |
| Backend old/new | `0c8278a3363cb98fd6933388e75809a7ad5aa75d` / 39396539229 | Six original input/comparison ZIPs; all six jobs successful, all eleven operations retained, independent replay exactly matches | One functional pair: 481→372 seconds, runner minutes 8.016667→9.783333; no statistical/causal speed claim |
| Android basic smoke | `688925dc36bfc3f8c65a590053e0f1e91651cf8d` / owned emulator and real TLS API stack | Actual native process, source tree, debug APK and original UI captures verified | Basic auth/workspace/settings/logout only; no stable signing/publication, physical/media or capacity acceptance |
| Windows basic smoke | Tested checkout `8da14d5a77ab1676e4631ed49228b089dffac93a`, API head `89e1e30dbcd3707cf59839c6108e15c7656ac194` / 39375469807 | Four original archives, real native recovery/GUI/SFU jobs, eight capture hashes/six unique images verified | Only difference from frozen688 is one inert owned Markdown marker, explicitly verified; no source relabeling, stable release or old-client promotion claim |
| macOS smoke | `688925dc36bfc3f8c65a590053e0f1e91651cf8d` / local QA build | arm64 debug build and deep ad-hoc signature verified | Runtime **NOT_RUN**: Mac locked; no repeated Keychain/password/unlock request; not pinned hosted macOS release evidence |
| Security negatives | Checkout8da14d5 / 39375469807 | Original contracts suite witness: 1093 passed/18 skipped of1111; selected critical suites have no skip paths; 27 source hashes and 19 shell fixtures verified | Focused producer/artifact/signature/health/cancel-race denial evidence, not production fault acceptance; no test assertion rerun |
| Configuration rollback | `0c8278a3363cb98fd6933388e75809a7ad5aa75d` / local candidate `916c647c9fba704c4dc5e711b71684758435cea2` | Six fixed checks PASS, 50 configuration paths only, 13 product/evidence subtrees identical; source branch restored | Candidate not pushed/merged; eight focused routing subcases are not eight new GitHub control PRs; no application or production rollback |

The raw JSON records contain archive IDs, byte counts, digests, public source
coordinates and actual interval data. They contain no artifact download tokens,
private test logs, credentials or generated media. Historical failed outcomes
remain in the existing evidence history; prescribed shadow samples are not
failure retries.

## Capture variation

All 35 PNG digests from Flutter legacy1 match new1. Legacy1 versus new2/new3
matches 33 of35. The two admin-media desktop/mobile captures differ only in the
minute digits of the last successful refresh time. Four original visual archives
were hash verified; eight original images were viewed at source resolution, and
six pixel comparisons confirm all pixels outside the timestamp rectangle are
identical. Old1 versus old2 has the same variation. The existing handler records
`DateTime.now().toUtc()` and the panel displays that time; source hashes match.
No product code or screenshot baseline was changed for this finding. These are
synthetic widget captures, not native/media acceptance.

## Source boundaries and remaining work

The retained partial manifest for frozen688 records **8/16**, zero verification
errors and NO-GO when evaluated on its original evidence-only descendant. That
is a historical assessment, not current-master readiness. The new native manual
publication implementation has separate source-bound tests and PR evidence;
old source receipts are not renamed to qualify it. Metadata-only publication of
these records does not itself execute or qualify a new product release.

The owner chose to keep environment/tag settings unchanged. The new native
manual-master fix uses the existing production reviewer and queue; actual
platform signing/publication still requires its independent review. Producer
review is separate from installation approval. Restricted operator account/key
and root-owned helper boundaries, current server release/install/compatible
rollback, native candidates/promotion, after observation and authenticated owner
GO remain required. The seven unfinished leaf issues and epic stay open.
