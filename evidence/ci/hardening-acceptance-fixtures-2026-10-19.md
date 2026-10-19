# Hardening acceptance fixture follow-up, 2026-10-19

The initial #420 head `0be02eadad47c00e08ebc50a40f8e858684b4b6c` activated existing
workflow acceptance. These are failures, not accepted native/media evidence:

- [SFU run 39169982563](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39169982563),
  job 117800830088: report generation raised `AttributeError: Stack.binary` after
  the fixture switched to a container-built API. The correction checks that the
  active container is registered and still has the owned label, copies only its
  public `/api` executable to a disposable private directory, hashes it and removes
  that temporary copy. It does not substitute a hash of another host binary.
- [Next-client run 39169982553](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39169982553),
  job 117800830266: the enabled file input resolved, then setInputFiles timed out
  after 20 seconds for the initial 5/5/25 MB batch. No successful upload receipt
  was produced. Timeout/retry/HTTP assertions were not weakened.

The upload fixture now writes the same zero-filled files in its owned private work
folder and uses native local file paths. Playwright's buffer path base64-serializes
and decodes the payload on the browser UI thread; its path mode uses the browser's
native file selection. Two owned headless CDP controls on this Mac, using the locked
Playwright 1.63.0, selected exactly [5000000, 5000000, 25000000] bytes:

| Control | Buffers (s) | Native paths (s) |
| --- | --- | --- |
| Initial transport comparison | 5.756632 | 0.007187 |
| Corrected fixture helper | 7.034690 | 0.004526 |

These n=2 local transport observations support removing avoidable serialization;
they do not prove the precise hosted timeout cause, a CI p95, product upload
acceptance, native focus/visibility or any media/capacity claim. The actual hosted
scenario must pass again. Its unchanged reservation, real 507/retry/cancel/scope,
TEXT/DM persistence, native hidden-window and protected-context checks remain.
The 20-second action timeout and real file sizes are unchanged. All private files
remain under the existing temporary work directory and are removed by the harness.

Focused tests were written before implementation. Three executable identity tests
check actual copied bytes/cleanup and foreign/missing ownership rejection; two Node
tests check real file paths, exact sizes/bytes, overwrite, traversal, foreign roots
and invalid size rejection. All pass. Full local Python suite: 592 PASS (39.345 s);
source-pinned actionlint and workflow policy PASS. Hosted acceptance for the revised
head is still pending at this checkpoint; keep #386 and parent #382 open.
