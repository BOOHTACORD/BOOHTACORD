# Windows native notice gate

Official publication run 43702552790 built the complete Windows distribution,
then rejected it before publication. No public 1.0.56 assets were published.
The canonical Windows 1.0.56 tag remains bound to fbeb51b39f51eacc91c607e3be96f0e6fd550830.
The replacement native source identity is 1.0.57+93, release order 72.
Web remains 1.0.56/r64. Android/macOS publication is outside this packet.

The pinned upstream `git archive` inherits Windows autocrlf conversion. All
four upstream license/README files arrived with CRLF. Replacing CRLF with LF
reproduces the independently pinned canonical SHA256 values in engine.json;
the Rust standard-library notice already matched. The license text did not
change. The release verifier correctly rejected the changed bytes.

Production staging now canonicalizes upstream notices, authenticates every
file before writing, and validates cached delivery without normalization.
A new cache directory avoids reusing pre-fix CRLF artifacts. Tampered sources
and cached notices remain rejected. The publication verifier is unchanged.

Regression checks cover LF and CRLF source inputs, byte-identical pinned
delivery, altered upstream text and altered cached delivery. The real local
Windows source archive is also staged through the same function, independently
of the synthetic distribution fixture. Official replacement publication and
public asset verification remain pending until their runs complete.
