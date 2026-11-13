# Issue #688: synthetic matrix timing

- Source base: `cb1d9a92ebd0cfa77b6308228b81e2147cb30cbf` plus this
  benchmark packet. One real projection row was cloned into 1001 independent,
  explicitly synthetic feature records; no runtime or release states were inferred.
- Command from repository root after locked Web dependencies and Chromium:
  `node tools/product_map/viewer/benchmark.browser.cjs`.
- Host: Intel Core i7-12700, 137191239680 bytes physical RAM, Windows 11;
  Node 24.18.0 and headless Chromium 153.0.8010.12 in WSL LocalAI,
  viewport 1440 × 900. Three fresh pages in one warmed browser process.
- Observed navigation to 1001 rendered rows: 300, 306, 189 ms. Filtering to one
  row through the search input: 51, 24, 12 ms. These are single-machine
  observations, not a performance guarantee or a cold-start benchmark.
- A later repeat with the committed cross-platform Python selection measured
  686, 300, 178 ms for navigation and 118, 14, 11 ms for filtering.
- The browser verifies counts before and after the filter. No architecture
  graph nodes were generated in this fixture. The required large-graph
  aggregation and full #688 performance acceptance remain NOT_RUN.
