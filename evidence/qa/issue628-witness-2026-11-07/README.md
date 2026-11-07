# Issue 628: current-master passive witness

Observed 2026-11-07 on source `cc4fbb4265709104c92d9ff085384bfb1ad2dbee` with the project's unchanged `python3 -m tools.qa.client_lifecycle.run --critical --portable-proxy`, separately at widths 1440 and 393. Both exited 0 and removed their owned stack. The picker boundary used synthetic animated canvas/audio; real API, LiveKit, the configured patched Egress and built Web were used. The 30-second producer cadence and original 45-second browser assertion were not changed.

| Width | Client preview refresh | Passive file observations | Result |
| --- | --- | --- | --- |
| 1440 | 33.038 s | Three distinct file SHA-256 values with JPEG start/end markers at one hashed path. | PASS_SCOPED |
| 393 | 33.000 s | Three distinct file SHA-256 values with JPEG start/end markers at one hashed path. | PASS_SCOPED |

At 393, one hashed Egress job appeared in file/image-category logs, and the file hash changed approximately 0.9 seconds before the client refresh observation. This timing is compatible with the expected chain but does not prove causation: logs did not link the job to the hashed file, and exact source-frame counters, import revision, notification and authenticated GET were not captured. One additional unqualified error-category line was observed; its relation to the job is unknown. The 1440 log parser did not recognize the log format, so its job observation is NOT_RUN. The 393 parser was expanded for plain-text logs without changing the tested runner. JPEG markers do not by themselves prove full decode; the existing browser assertion did observe a decoded thumbnail.

The receiver images at their source raster sizes were reviewed: the synthetic preview is visible in both. At 393 the resolution badge and participant names are truncated. In the artificial 393 x 160 short-height case the dock overlaps the stage. This is not approval of the full visual gallery. Sanitized JSON retains only hashes, event classes and selected timing stages; observer sources are included. Raw logs, identities, tokens and image content are not retained here.

This evidence does not complete #628: job-to-file-to-import-to-hint-to-client witness remains incomplete, the historical canonical selection/base and full visual review remain unverified for this final source, and actual production Egress image/runtime smoke is not confirmed. An attempted read-only SSH image inspection was denied by public-key authentication; production was not changed.