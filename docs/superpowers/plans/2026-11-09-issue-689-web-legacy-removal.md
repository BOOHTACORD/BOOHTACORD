# Issue 689: remove unused Web roster streaming/polling

**Route:** `clients/web/src/voice`, legacy roster transport retirement.

- [x] Move retained-age, retry ownership and empty/unavailable assertions to the shared-socket state.
- [x] Remove unused EventSource and polling implementations after confirming no workspace dependency.
- [x] Run affected and full Web tests/build; static repository guard, full-stack and release gates remain separate.
