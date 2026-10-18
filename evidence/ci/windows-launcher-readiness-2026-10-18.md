# Windows GUI launcher readiness regression

PR #408 run `39160294980`, head `e67afffaac11cacf53d4e8d21b89477f624f2272`,
failed job `117772294225`: `launcher_not_unique`, stale journey step `voice_listener`.
The assertion required exactly one hit-testable launcher immediately after the
SFU state became connected; it did not distinguish zero controls from duplicates.
No failure capture was retained by that fixture, so the exact observed count and
failed launcher cannot be reconstructed. This record does not label it a proven flake.

The focused widget reproduction with both shipping control types finds one target
per launcher. A delayed-render reproduction requires a frame after the connection
state changes. The fixture now observes frames for at most five seconds inside the
same voice connection attempt. A duplicate fails immediately; a missing control
still fails. The four OS-input/real-SFU cases and their assertions are unchanged.
Each launcher case has its own step code. On failure the disposable runner retains
only controlled failure codes and a bounded synthetic PNG, never private config/logs.

Local results: four launcher/action scope tests PASS; three failure-retention/GUI
contract tests PASS; 20 baseline tests PASS; focused analyzer reports no issues. Native Windows acceptance remains pending a successful CI run;
Mac-hosted widget tests do not prove Windows GUI or media acceptance.
