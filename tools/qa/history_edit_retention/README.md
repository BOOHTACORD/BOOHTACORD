# Owned Web history acceptance

Run from the repository root on a local Linux Docker host:

```sh
node --test tools/qa/history_edit_retention/test_seed.mjs
python -m tools.qa.history_edit_retention.run
# A scoped retry can select only the failed width:
python -m tools.qa.history_edit_retention.run --width 393
```

Requires the pinned Node/Python toolchains, installed Web dependencies and the
matching Playwright Chromium. Uses fresh label-owned database/API/Tempo/proxy
and LiveKit/Egress resources on loopback; it never connects to production or a supplied database.
An existing `.out/history-edit-retention` is rejected to preserve earlier results.

The built application and secure-cookie API exercise a 1000-message editing
roundtrip, exact draft/selection, focus through resize and a real concurrent-save
conflict at 1440px and 393px. The wide run also checks 20 finite history datasets:
50/500/5000/10000 rows, 0/50/100% reply references, plus 50/100% unavailable
cross-scope references. The fixture uses SQL only inside its verified owned DB;
it does not attest admission of such legacy references through business APIs.
Application requests, response bodies and ACL decisions are never mocked.

Reports contain bounded counts/timings, heap observations, source fingerprints
and cleanup status. Screenshots contain only synthetic data. Retained heap is
measured after explicit GC and is not peak memory or a production SLO. Short
local browser runs do not establish physical/native/media acceptance.

The critical client-lifecycle journey runs the 1000-message regression before
its existing session-revocation checks. The full 20-dataset matrix stays a
separate bounded acceptance command rather than adding it to every PR.
