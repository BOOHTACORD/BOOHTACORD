# Windows Authenticode preparation, 2026-11-08

- Observed: the released 1.0.52 Windows executable, record plugin, and two
  Velopack binaries in its full package are unsigned. The installed executable
  on the local PC runs; this does not establish behavior on the affected PC.
- Windows SDK 10.0.26100.0 `shared/ntstatus.h` maps the reported `0xC0E90002`
  to `STATUS_SYSTEM_INTEGRITY_POLICY_VIOLATION`: Application Control blocked the
  named file. The particular policy and its reasons still require the affected
  PC's CodeIntegrity event; Smart App Control is not confirmed specifically.
- Certificate discovery: no usable code-signing certificate was returned from
  CurrentUser/My or LocalMachine/My on this PC. Repository and production
  environment action metadata revealed no Windows code-signing configuration;
  organization-level metadata was inaccessible (HTTP 403). The existing
  `RELEASE_SIGNING_PRIVATE_KEY` is used by the server bundle workflow and is not
  evidence of an Authenticode certificate.
- Source checks: focused Python tests exercise configuration, unsigned/invalid
  binary rejection, preserved signatures, archive contents and installer gates.
  These use simulated signing states and do not prove a trusted signature.
- NOT_RUN: signing with a trusted provider, trusted timestamp validation of a
  built installer and every packaged binary, Smart App Control enforced launch,
  and inspection of the affected computer's CodeIntegrity events. No production
  workflow or server deployment was run by this change.
