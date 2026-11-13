# Product Map Projection Implementation Plan

> **For agentic workers:** Execute this first packet directly; later packets require separate plans and acceptance.

**Goal:** Import every existing parity ID without inventing native or release status.

**Architecture:** Read the existing parity registry, validate it using its existing validator, then project five independent client entries. Keep unproven revision and release fields unknown. The projection is not a second source of truth.

**Tech Stack:** Python 3, unittest, existing JSON parity registry.

---

### Task 1: Import existing scenarios

**Files:** `tools/product_map/projection/importer.py`, `test_importer.py`, `test_real_registry.py`.

- [x] Verify duplicate IDs and missing source platforms fail.
- [x] Preserve every existing ID; add separate Windows and macOS unknown entries.
- [x] Run `python -m unittest tools.product_map.projection.test_importer tools.product_map.projection.test_real_registry` and require success.

### Task 2: Independent status and presentation

**Files:** `tools/product_map/projection/status.py`, `compare.py`, `render.py`, their tests, and `tools/product_map/__main__.py`.

- [x] Derive source revision status without inferring release or runtime PASS.
- [x] Compare two clients and render escaped Markdown with visible unknowns.
- [x] Run `python -m unittest tools.product_map.projection.test_status tools.product_map.projection.test_compare tools.product_map.projection.test_render` and require success.

This packet does not deliver issue #688: catalogs, complete ownership, secure interactive viewer, release receipt validation, CI enforcement, and full acceptance are outstanding.
