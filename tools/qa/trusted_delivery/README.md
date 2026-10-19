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
