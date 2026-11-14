# Issue 687: publisher key failure cleanup

Status: PARTIAL, local Windows fixture. A simulated OpenSSL generation failure wrote partial bytes and left a private-key file. The regression test failed before the change and passed after generation errors were made to close the descriptor and remove the newly created file. The missing-tool case and real OpenSSL signing/verification and promotion fixture round trips also passed. No production key was created.

Failures during public-key extraction and malformed public DER were also reproduced and then verified to remove the new private-key file. NOT RUN: failures during public-key publication, Windows private-key ACL enforcement, real signing credentials, published update and rollback. The Windows test that assumes Unix mode `0600` is not evidence of Windows ACL security. Signed release acceptance remains open.
