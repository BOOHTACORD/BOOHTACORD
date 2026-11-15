# Selective CI retry receipt aggregation

Scope: receipt collection only. No DSP, Flutter application, or server rebuild
was performed for this diagnosis. Additional acceptance remains NOT_RUN at
the owner's request; mandatory repository checks remain enabled.

CI run 43719912933, source dc7bb9412dc52cb35a37ef6493fecedab72f14dc:
Android dependency download and lifecycle failed on attempt 1, then passed
on selective attempt 2. The two aggregators still failed because their
download patterns excluded successful peers' attempt-1 receipts.

The fix keeps source/run/namespace-scoped archives separate, selects each
profile's newest available execution, and validates its original attempt.
Current parent jobs must all succeed. Foreign, missing, future, failed or
tampered evidence cannot fall back to an older success. Legacy flat manual
verification remains strict to the current attempt.

PASS: 34 focused collector, validator and workflow tests. New regression
tests failed against the previous implementation before the fix.
PASS: replay of 9 original hosted artifact ZIPs, with sizes/SHA-256 checked:
Flutter dart/Kotlin/macOS attempt 1, Android attempt 2; actual next/SFU
attempt 1, lifecycle attempt 2. Receipt bytes were not rewritten. All selected
reports, captures, cleanup and source/run identities passed the existing
validators. The original Git blob supplied the Linux plan bytes (hash
4f0f7a3b261feefcbf8429d44f598146dc54c1404224d172d8d8d4e6c1bec8d3),
avoiding Windows checkout line-ending conversion during this local replay.
The failed hosted run/check state was not altered by this component replay.
