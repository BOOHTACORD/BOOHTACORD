# Web delivery and unchanged-schema SQL replay

Web 1.0.56 was blocked before replacing API/Web containers: historical SQL
0015 narrowed voice_leases_revocation_reason_check and rejected rows allowed
by the later migration 0068. The migration runner re-executes every SQL file.
No historical SQL or existing lease data was changed for this recovery.

The running 6f3f536d33205d6a5e2a39829924137af4e6e65b release and signed target
4c609c83b159419e7819c2fb46fa3ef3cd7e1d5f had exactly the same 68 migration
names and hashes. The observed schema matched the previous verified receipt.
An owner-authorized canonical installer invocation used a private rollout
copy with only that unnecessary SQL invocation replaced by an explicit no-op.
Signed release files stayed unchanged. Source, signatures, image digests,
single-writer guards, health, schema and persistent-volume checks remained.

PASS: canonical installed-source fresh readback, including API/Web/worker
source identities, unchanged schema and persistent volumes. The original
failed GitHub installation is retained as failed; operator recovery is a
separate result. Successfully acknowledged transport copies were removed.
PASS: public Web 1.0.56/r64 receipt, RNNoise release-v0.2 manifest and WASM
SHA-256 6e45ec094afad2bcd816ff0f1a55e6d34ffa0935f8aa85cf70ff741834904e41;
public API health OK. Browser speech acceptance remains NOT_RUN as requested.

The permanent installer change applies the same rule after authenticating
both manifests. It adapts the recognized launcher in private temporary space
only for identical nonempty inventories. New, changed, missing or empty
inventories retain the migration command; unknown historical launchers retain
their behavior. It preserves signed runtime files and existing safety checks.

PASS: 12 focused installer/rollout tests on Linux, including actual Bash SQL
invocation/no-op, unknown/changed inventories, symlink rejection, stale source,
single-writer preflight and passing authenticated current state to rollout.
PASS: the exact repository source-hash check. No DSP, Flutter or server image
was rebuilt locally. Changed migration inventories keep the existing replay
behavior; migration-ledger design is outside this client-only rollout fix.
