# Issue 687: release readiness, 14 November 2026

This is a source and local-test review, not a release authorization.

| Target | Existing delivery contract | Issue 687 status |
| --- | --- | --- |
| Windows | Manifest validation permits either `signed` or `unsigned`. | Local build was unsigned; the requested signed delivery is NOT_RUN. |
| macOS | Manifest validation currently requires an ad-hoc signature; notarization is recorded NOT_RUN. | This does not establish Developer ID signing or notarization; a macOS release build is NOT_RUN. |
| Android | Manifest validation requires the expected signing-certificate fingerprint. | Only a debug emulator smoke was run; signed release is NOT_RUN. |
| Web | Default build succeeds and the experimental v0.2 asset guard fails closed. | Release deployment and acoustic acceptance are NOT_RUN. |

The current native release validator alone is therefore insufficient evidence
of the requested signed Windows/macOS delivery. Do not publish the audio feature
until platform-specific signing, model rights, attribution, rollback and all
issue acceptance gates are verified. No release or deployment was performed.

On Windows, the native release contract tests initially failed because their
isolated test environment cleared `PATH` before launching real Git. Retaining
only the necessary executable-search and Windows system-root variables in the
two real-Git fixtures allowed all 14 Python checks to pass. The 17 Node publisher
checks also passed; neither test suite creates or publishes a real release.

The existing desktop signing-key creator left an empty private-key file when
OpenSSL was unavailable. A regression test reproduced that behavior; checking
the executable before file creation fixes the missing-tool case. On Windows,
that test and ten signing, catalog and rollback fixture tests passed with an
explicit local Git OpenSSL. The separate Unix `0600` mode assertion still fails
on Windows, where private-key ACL protection remains unverified; inherited
permissions must be checked at the real key location before using it. The
preflight does not cover executable removal after the check or all other
key-generation failures. No project key was created and no rollback was run.
