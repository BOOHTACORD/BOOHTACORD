# Issue 249: public catalog and release artifact readback

Observed 2026-11-09 02:40 UTC. Narrow read-only evidence; issue remains open.
No authentication, production mutation, installation, update or restart.

- `GET https://v.bootybay.ru/api/v1/client-updates?platform=windows&distribution=direct&channel=stable&arch=x64`: HTTP 200, `Cache-Control: no-store`, `application/json`, catalog revision 33, published target `windows-direct-stable-r67`, version 1.0.52, build 88, action `open_download_page` pointing at the Windows 1.0.52 GitHub release.
- Android direct/stable/arm64 selector: HTTP 200, `Cache-Control: no-store`, revision 33, target `android-direct-stable-r48`, version 1.0.34, build 67. This is only a current readback, not proof other platform entries were preserved by a promotion.
- The referenced GitHub Windows release was published, non-draft and non-prerelease. Streamed release bytes were hashed independently and matched the release SHA256SUMS and GitHub asset digests:
  - `artifact-manifest.json`: 12,182 bytes, SHA256 `4a1e34f48e95c08f5324f7c57f7db1d591814309beb6fa7d7888a5134e0fc2a1`.
  - `BOOHTACORD-windows-v1.0.52-x64.zip`: 29,999,272 bytes, SHA256 `1f2001efc6d2756a7478563261ccae1d1699adf73eb42c7aca52b9ff1fef8d1b`.
  - `boohtacord_desktop-stable-Setup.exe`: 39,007,655 bytes, SHA256 `a41d13dacf2f6ec99c9f1cda14c114a86839d83457ae171107a44bac08886dbf`.

The present target has advanced beyond issue 249's historical revision 29 / Windows 1.0.38 target. The checksum match is an integrity comparison, not proof of publisher authenticity. Old Windows 1.0.32 build 46 observing and installing an update, executable identity, post-update state, deployment lineage, restart and concurrent promotion checks remain NOT_RUN. This observation cannot close the issue or prove the server source revision. The user has prohibited server deployment.
