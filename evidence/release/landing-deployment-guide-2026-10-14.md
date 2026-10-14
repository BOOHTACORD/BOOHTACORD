# Landing deployment guide — 2026-10-14

Scope: the root `index.html` published by GitHub Pages. Baseline is
`499e9034b6bf78c0a0214645dd922b7a4e70dff8`.

The page adds deployment prerequisites, public media ports, runtime settings,
test-only source builds, administrator bootstrap through stdin, API health and
client connection instructions. Production delivery remains the existing
signed-bundle workflow. Promotional headings and page metadata use plain copy.

Sources: `README.md`, `deploy/README.md`, `.env.example`,
`deploy/compose.yaml`, `deploy/compose.dev.yaml`, `deploy/operators.yaml`,
`deploy/livekit/compose.yaml`, `deploy/caddy/Caddyfile`, and the development,
release and administrator runbooks. No runtime, requirements or contracts change.

Validation:

- PASS — unique HTML IDs and all internal fragment links resolve.
- PASS — all four displayed shell command blocks pass `bash -n`.
- PASS — production/development Compose configuration resolves, and
  `python3 -m tools.verify.compose_layout.check` agrees with the documented
  topology. The installed Compose executable was exposed as a plugin using an
  isolated temporary Docker CLI configuration; no host configuration changed.
- PASS — browser inspection at desktop width and 390 px: readable headings,
  deployment cards, settings table and command blocks; page has no horizontal
  overflow, while long command blocks scroll within their containers.
- NOT_RUN — fresh Linux installation, production delivery and physical media
  acceptance. This documentation change does not close those gates.

Screenshots are local review artifacts and are not committed.
