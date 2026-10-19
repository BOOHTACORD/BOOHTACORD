# Actual next failure and finite diagnostics (#398 / #402)

PR455 run39323887499, tested merge06e607dc20d596ea56accf16dccf9f86cbdb4a08,
job118304707305 failed its original next controller. The retained public artifact
12221222283 (543bytes, ZIP SHA2562114f1d65a65a1383377b7aa34992763742eec3f0c37037af6931a05a8bf7c24)
was independently downloaded and checked. Its result is FAIL/ValueError at
operation1 after165.932s; operation0 passed and owned resources were removed.
No detailed controller stage was retained. The private child log is deliberately
not published; the cause of this historical failure remains UNVERIFIED, not a
confirmed flake or a passing run.

Before the diagnostics fix, four new focused methods produced three failing
assertions and six missing-function errors. Controller failures now record only
finite stage/capacity/error-class enums; the wrapper validates strict bounded JSON
and publishes a canonical serialization, never raw logs, exception text, process
arguments, credentials or message bodies. Missing diagnostics do not invent a
cause; malformed/duplicate/foreign/linked data is rejected without changing FAIL.
Visibility witness and actual next controller are separate original operations,
so their failure indices are distinct. Assertions and runtime acceptance are
neither retried nor ignored.

The first focused integration check passed14 methods in0.021s. Hosted acceptance
of the new diagnostics remains pending. This record does not close #398/#402 or
assert that the historical runtime failure is fixed.
