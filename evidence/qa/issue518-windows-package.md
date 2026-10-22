# #518 — pinned Velopack publication format

Windows Release 39767005427 successfully tested, analyzed, compiled and packaged
1.0.46, then failed before publication. The release validator expected a name
ending in `-1.0.46-full.nupkg`, while pinned Velopack 1.2.161 with channel stable
actually produces `boohtacord_desktop-1.0.46-stable-full.nupkg`.

The actual name is retained in the source-bound installer transfer receipt of
successful Windows CI 39764639901, artifact 12420770191. This is CI packaging
format evidence, not a claim that its QA-purpose binary is a public release.

The native asset fixture was changed to the actual pinned-tool format first;
the Windows valid-package case failed RED. The release validator now matches
the exact measured stable filename, including application ID, version and
channel. Four focused asset tests PASS, including wrong version, preview channel
and foreign application rejection. The pinned producer and reviewed SDK inputs
are unchanged. Source, manifest, checksums, ZIP traversal and QA-purpose rejection
remain required and unchanged.

Existing unpublished Windows tags 1.0.45 and 1.0.46 remain at their original
commits. The corrected Windows release is 1.0.47 (82), order 61. Shared Flutter
defaults and build identities advance together under the existing consistency
rule. Application feature behavior from #518 is unchanged; already published
Android/macOS and the signed iOS 1.0.45 receipts retain their exact source.
Final CI and public Windows/portal readbacks follow on #518 before closure.
