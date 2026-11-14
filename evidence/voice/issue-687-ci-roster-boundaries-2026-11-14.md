# Issue 687: isolate the remaining CI failure

On dff6921be4272c6137a698180eaaabd81f10aa4c all three auxiliary workflows
passed. Required CI 43615295660 failed only the lifecycle runtime; its fan-in
and final required check consequently failed. Windows build/GUI/native tests,
Flutter/Dart/macOS/Android, browser/audio/SFU and backend jobs passed.

The lifecycle artifact identifies operation 3, last completed milestone
`roster-transport-restored`, ValueError, and successful owned-resource cleanup.
It does not retain the underlying private browser assertion or prove its cause.
The earlier macOS download timeout did not recur on this head.

The unchanged roster outage assertions are moved into roster_outage.mjs, with
finite milestones after SFU pause, failure event, banner, copy, final failure
UI and recovered API. Timeouts, expected copy, ACL/empty-roster assertions,
screenshots and finally-unpause behavior are preserved. Public receipts retain
only allowlisted completed milestones, never raw messages, cookies or log tails.
The new receipt regression failed for all six boundaries before the change.
It is explicitly included in the lifecycle CI unit command.

Focused receipt/privacy/inventory tests, six Node control/diagnostic tests,
both JavaScript syntax checks, Web import verification and parity pass locally.
The broader controller diagnostic suite cannot pass on Windows (fcntl absent);
the attempted WSL run failed to start its distribution with E_FAIL. No mocked
fcntl or weakened CI gate was substituted. Real lifecycle rerun is required.
This change improves localization; it does not fix or waive the runtime failure.
No release or server deployment.
