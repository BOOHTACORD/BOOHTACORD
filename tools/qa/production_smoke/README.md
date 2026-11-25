# Production smoke

Both server installation workflows run this bounded browser journey after a
successful install. The `production-smoke` environment holds credentials for a
dedicated ordinary member and is restricted to `master`; it has no production
SSH or signing credentials. The existing `production` environment controls
the separate approval before release jobs access production secrets.

The test verifies public API health and the exact installed source before and
after the journey. Chrome logs in, opens the `QA Production Smoke` voice channel
in the `TEST` section, requires it to be empty, joins as a listener, publishes
a synthetic microphone track over a connected WebRTC peer, leaves and logs out.
Chrome uses a fake audio device and never captures the host microphone. The workflow fails if a
check fails, credentials are unavailable, or the installed source changes.
The smoke shares the non-cancellable production lock; the automatic route may
wait behind another install and then fail on a source mismatch.

Smoke failure is an incident signal, not an automatic rollback: the new
release may already be installed. Investigate the workflow and production
before any approved recovery. Never publish credentials, session cookies,
candidate addresses, SDP or message content. The test does not verify a
physical microphone, two-party audio playback, screen sharing, native clients or physical
devices; those remain separate acceptance checks.

The smoke account is an ordinary member and can access channels granted to
members. Keep its credentials in the restricted GitHub environment, not in the
repository. Do not put human accounts or production administrator credentials
in the smoke environment.
