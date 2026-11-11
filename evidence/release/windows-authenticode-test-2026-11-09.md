# Windows Authenticode test, 2026-11-09

- GitHub organization Actions settings showed no organization secrets and no
  organization variables. Repository and production environment secret names
  did not identify a Windows signing certificate; secret values were not read.
- A disposable copy of the 1.0.52 record plugin was signed using the Windows
  SDK 10.0.26100.0 SignTool and a one-day non-exportable self-signed test key.
  SignTool rejected `https://timestamp.digicert.com` with `Invalid Timestamp
  URL`; the RFC 3161 HTTP endpoint completed signing with a timestamp and the
  requested certificate. Windows did not trust the self-signed signature and
  the prepared verification correctly rejected it. The temporary key and file
  were removed; no trusted root was added.
- Local Smart App Control registry state is 0 (Off); a successful local launch
  cannot establish the behavior under an enforced App Control policy.
- NOT_RUN: signing using a publicly trusted certificate, the complete signed
  Velopack installer and package, launch with Application Control enforced,
  and the affected user's CodeIntegrity event. This test does not prove a fix
  for the reported policy block. No server deployment was performed.
