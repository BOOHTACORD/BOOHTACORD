# Issue #688: partial system topology viewer

- Scope: source-linked documentation viewer only; not application runtime,
  publication, release acceptance, device acceptance, or full #688 acceptance.
- Base before this packet: `e09f4598129b1b103051463cdfc8ffea292c3d83`.
- Local browser: Chromium 153.0.8010.12, headless, device scale factor 1;
  viewports 320 × 900 and 1440 × 900. Static generated file, no server.
- At source resolution the desktop screenshot shows 13 nodes and 14 directed
  connections; the mobile screenshot shows a horizontally scrollable graph and
  readable component and relationship lists. The graph is partial. Labels and
  lists distinguish a test file from a passed test.
- Local screenshot SHA-256: 320px
  `c255b714e6aed37e78415c294a6a1f1e7ea5fc71830c4bc854d26a6ae8f570f8`;
  1440px `e4244696e0b143c413f9d64f4c7d13098af30e0895d5000beb2b7a69b816efad`.
  Images remain local QA artifacts and are not checked into Git.
- Browser regression checks graph nodes, relationships, one shared Flutter
  component, four adapters, responsive scrolling and the parity matrix.
- Native real-stack, physical Android/iOS and release evidence: NOT_RUN for
  this documentation viewer. Full inventory, authoritative evidence and all
  acceptance criteria of #688 remain incomplete.
