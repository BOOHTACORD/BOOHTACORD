# Issue 687: publisher key failure cleanup

Status: PARTIAL, local Windows fixture. A simulated OpenSSL generation failure wrote partial bytes and left a private-key file. The regression test failed before the change and passed after generation errors were made to close the descriptor and remove the newly created file. The missing-tool case and real OpenSSL signing/verification and promotion fixture round trips also passed: four tests total. No production key was created.

NOT RUN: failures during public-key extraction or publication, Windows private-key ACL enforcement, real signing credentials, published update and rollback. The Windows test that assumes Unix mode `0600` is not evidence of Windows ACL security. Signed release acceptance remains open.
