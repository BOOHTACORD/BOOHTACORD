# Native upload proxy response regression

Use the exact Linux Caddy2.10.0 binary and SHA from the approved pinned image.
The runner rejects an absent/wrong binary and requires Go1.26.4. No skip or
synthetic proxy substitutes for the real native Caddy process.

```sh
GOTOOLCHAIN=go1.26.4 python3 -m tools.qa.upload_proxy.run \
  --caddy /absolute/path/to/caddy --sha256 EXACT_VERIFIED_SHA256 \
  --output .out/issue134/native-proxy-check
```

Only Go test sources are overlaid into the existing upload_request package;
the implementation and production Caddyfile are read directly from the target
checkout. Owned HTTP1 loopback processes use admin/TLS disabled and isolated
XDG/temp directories. Cleanup stops only the child process created by each
fixture. MAIN containers, ports, accounts, settings and trust stores are unused.

The fixture substitutes its owned upstream address/HTTP listener and disables
admin/TLS in its private Caddyfile copy. Production route ordering and response
matching remain unchanged. Headers-only/partial TEXT and DM requests must
receive complete408/UPLOAD_TIMEOUT with default client keep-alive. Valid slow
progress/success must retain a reusable connection, as must non-upload408,
wrong methods and unmatched path suffixes. Source/config/binary/log hashes and
explicit PASS/FAIL counts are retained in receipt.json.

The40ms/300ms fixture proves protocol and scope, not real60s/900s durations.
Normal TLS through the full Caddy/API/PostgreSQL stack remains a separate
mandatory release acceptance. Baseline and failed candidates are retained.

The existing required `contracts / contracts` job invokes
`python -m tools.qa.upload_proxy.ci` after Compose validation, unconditionally.
It runs on hosted Ubuntu24.04 x64 with Go1.26.4. `pin.json` binds the reviewed
Caddy2.10.0 image manifest, Linux binary SHA256 and embedded Go1.24.2. Docker
only creates a unique labelled stopped container to copy that binary; identity,
image and stopped-state guards must pass before its removal. No image pruning,
service/container execution or user-machine Docker is part of this CI wrapper.

| Protects | Command/platform | Mandatory trigger | Result location |
| --- | --- | --- | --- |
| Early upload408 delivery plus route/success/slow-progress keep-alive scope | `python -m tools.qa.upload_proxy.ci`, hosted Linux x64, exact pinned native Caddy | Every invocation of the existing required contracts workflow, including PR and server release validation | Always-retained `upload-proxy-<checkout-sha>-<run>-<attempt>`: `summary.json`, `native/receipt.json`, `native/native-caddy-test.log` |
| Discovery, missing/partial native result, failed extraction and owned cleanup | `python -m unittest tools.qa.upload_proxy.test_image tools.qa.upload_proxy.test_ci`; ordinary project Python discovery | Required contracts verification | Job log and source-bound native summary |

The hosted wrapper requires all12 reviewed PASS events, zero FAIL/SKIP, the
declared binary digest and successful owned cleanup. Missing dependencies,
evidence or cleanup fail the job. The artifact retains failures too. The local
unit tests mock Docker and do not substitute for the hosted native execution.
