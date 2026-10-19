# Trusted delivery acceptance (#395)

This harness records independent acceptance scopes. A successful transport
receipt is not a signed installation, deployment, rollback or full #395 PASS.
The existing #60 harness and its strict retained-runtime currency guard remain
unchanged. Historical #60 evidence does not attest the new delivery controller.

## Actual GitHub network transport

`qa-trusted-delivery.yaml` runs on a hosted Linux runner with only repository
contents/actions read permissions, no production environment, SSH credentials
or production concurrency group. The fixed retained master producer is run
39268498370 / source fe482078a2fa4e4964b6758770980d4b1a0b2fa6. Its identity is
revalidated with the shipping producer authority before and after downloading.

`python -m tools.qa.trusted_delivery.network` executes shipping
`authority.prepare`, `download.main` and `authority.recheck` in a fresh private
directory. The downloader obtains the real API redirect, keeps the API token
off the blob request, bounds the response, checks the actual ZIP size/digest
and atomically extracts the exact checksum-verified transport pair. No bundle
code, image import, host signature validation or install command executes.

The only uploaded file is `.out/issue395/network/evidence.json`, retained for
30 days with source/run/attempt identity. It records the actual controller and
shipping module hashes, selected producer, observed transport checks and explicit
installation/signature `NOT_RUN`. Errors produce `FAIL` without private error
text, URLs, API response bodies or token values. A reused output directory fails
before network access. All generated archives and private metadata stay ignored.

Run focused regressions with the project's Python/PyYAML environment:

```sh
python -m unittest tools.qa.trusted_delivery.test_network tools.qa.trusted_delivery.test_workflow
```

This workflow supplements the already recorded actual connector download; only
its completed successful run proves the new Python API/blob network path. A
queued, cancelled, failed or missing hosted run cannot close that scope or #395.

## Actual isolated installations and recovery

The existing **Compatible rollback acceptance** manual workflow has an optional
`installation` boolean, default **false**. The default still executes the original
QA-12 rollback. Select true only for the combined #394/#395 acceptance. Both modes
are exact upstream master, hosted Linux amd64, read-only GitHub permissions and
no production environment, production key or deployment queue. The authenticated
CI proof step still checks both successful master producers, current runtime
currency and compatible backend/schema/topology before creating any fixture.

Supply `current_source/current_run` for the newer qualified source and
`previous_source/previous_run` for its qualified ancestor. Their original CI
identities remain in `run.json`. The fixture begins at the previous source, then
installs the current source. The private setup-role adapter never changes source
labels, Git objects, image identities or successful producer claims. The current
controller is a separate clean checkout; shipping SSH transfers archive that
controller, while each real artifact remains bound to its retained source.

`python -m tools.qa.trusted_delivery.run --ci-proof <observed-proof.json>` requires
a clean tracked reviewed checkout, Node/locked Playwright, and the existing local
Unix-only Linux amd64 Docker isolation. It refuses an existing output directory.
It builds two **fresh** genuine SBOM/provenance-verified, smoke-tested signed QA
bundles, first cold and then with the same private bounded layer cache. Complete
bundle caching is disabled in this mode. Source-bound `build-<sha>.json` metrics
retain the actual stages, cache namespaces/import outcomes and Docker filesystem
before/after measurements. These measurements describe that filesystem, not exact
Docker-directory allocation, hard quotas, production signing or production speed.

The private RSA QA anchor is provisioned before either build. While its ephemeral
private key still exists, the fixture signs one immutable-conflict bundle with
identical OCI/runtime bytes and different semantically equivalent checks JSON.
The original artifacts are unchanged and the same public anchor verifies both.
The private signing key is deleted even on build failure. Loopback-only sshd and
its client/host keys exist solely inside the owned disposable controller. No SSH
port or Docker TCP/socket is exposed on the host; only the QA HTTPS loopback port
is published. The QA account has capabilities needed for the canonical installer;
this fixture does not attest the restricted production diagnostic account #399.

Two authenticated browser observers check all 15 phases: initial state, same-SHA
installation, upgrade, retry, interrupted-install maintenance/recovery, another
same-SHA retry, compatible rollback and restore, including each maintenance
banner and admission denial. Stable phases verify account identity, TEXT/DM and
attachment continuity, revision receipts and renewed admission. Four volume and
three network identities plus logical product/schema, attachment, TLS and proxy
fingerprints must remain unchanged. These are fingerprints, never copied data or
restore points. All 30 screenshots contain only controlled synthetic fixtures.

Interruption sends SIGTERM to the actual SSH client **during remote maintenance**.
Its shipping phase receipt must fail specifically at `remote_install` with
`interrupted`; remote completion remains **UNKNOWN**. The fixture observes the
canonical host lock held, waits for its independent release, then requires
maintenance off, fresh signed-source health/readback and unchanged state before
the recovery retry. A stuck lock, maintenance state or unhealthy source fails;
closing SSH is never taken as proof that remote Docker stopped.

Actual negatives additionally require SSH refusal, bandwidth-limited SCP killed
by the shipping timeout, valid-signature immutable mismatch at the canonical
guard, ancestor downgrade rejection, and a paused API failing HTTPS health and
fresh acknowledgement. It unpauses the owned API in `finally`, requires restored
health and an unchanged installed receipt, and rejects another attempt nonce.
Unexpected failures never count as intended negative PASS. There are no assertion
retries, substituted transport results, fake Docker or intercepted API responses.

Only public `run.json`, `delivery.json`, `negatives.json`, `browser.json`, build
metrics and synthetic PNGs are uploaded, under the existing 30-day retention.
Partial failure reports survive cleanup; logs, keys, cookies, private environment
and application data do not enter artifacts. The strict delivery validator binds
every success/failure to the exact controller/source, complete browser graph,
fresh readbacks, unchanged storage and immutable running image refs. Cleanup is
mandatory for an accepted final run. Actual hosted execution and visual review
must complete before recording PASS; unit tests or a dispatch are **NOT_RUN** for
runtime acceptance. Native publishing, production operations, #249 physical
Windows acceptance, capacity claims and independent owner cutover GO remain
separate gates.
