# Android recovery on reconciled source

Source `8cf04accf36102aba0616e9df6242dc56f64add9`; dedicated Android 35
emulator `BOOHTACORD_QA_ISSUE689`. An isolated Windows fixture ran PostgreSQL
17.6, LiveKit 1.13.7 and an API built from this source, with synthetic accounts
and a direct TCP media candidate. No production service was used.

The listener connected and stayed stable for ten seconds. The owned SFU was
stopped for 45 seconds and then restarted. During a failed retry the app kept
the selected channel and displayed recovery; it subsequently returned to that
same channel. The test and fixture cleanup completed with exit code 0.

Three 1080x1920 synthetic screenshots were inspected at original resolution:

- Before: `a1c0dfb30074a859242462b3d355e690cbc79d0221a1cbe73b71c0077584f122`.
- During retry: `53a756b60b1faf3441afed59644b6fba42a3551e0ee938e50680df70ab27269a`.
- After: `b5f50c81b1495c993654a97779ea413f96f4cfc3f3d7d5717bb46e5133072aa5`.

The recovery label and channel name remained visible during the interruption;
the connected status returned afterwards. This is one emulator and one
isolated listener path, not physical-device, audible-media, iOS or production
acceptance. The broader local feature gate remains FAIL/BLOCKED.
