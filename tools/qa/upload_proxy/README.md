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
