"""Fixed real controllers and required public reports; no configurable command input."""
import sys

PY=sys.executable
OPERATIONS={
    'lifecycle':[
        [PY,'-m','unittest','tools.qa.client_lifecycle.test_services','tools.qa.client_lifecycle.test_telemetry','tools.qa.critical_client_acceptance.test_stack','tools.qa.refresh_baseline.test_archive','tools.qa.upload_reservations.test_measure','tools.qa.upload_reservations.test_scenario','tools.qa.upload_reservations.test_client'],
        ['node','--test','tools/qa/critical_client_acceptance/requests.test.mjs','tools/qa/critical_client_acceptance/roster_observer.test.mjs','tools/qa/critical_client_acceptance/roster_diagnostics.test.mjs','tools/qa/critical_client_acceptance/sfu_control.test.mjs','tools/qa/critical_client_acceptance/roster_network.test.mjs','tools/qa/client_lifecycle/login_diagnostics.test.mjs'],
        [PY,'-m','tools.qa.refresh_baseline.run','--revision','BASELINE'],
        [PY,'-m','tools.qa.client_lifecycle.run','--critical','--width','1440','--output-root','.out/client-lifecycle'],
        [PY,'-m','tools.qa.client_lifecycle.run','--critical','--width','1024','--output-root','.out/client-lifecycle'],
        [PY,'-m','tools.qa.upload_reservations.run']],
    'next':[
        ['node','--test','tools/qa/next_client_acceptance/input_files.test.mjs','tools/qa/next_client_acceptance/failure.test.mjs','tools/qa/next_client_acceptance/navigation_fixture.test.mjs'],
        ['xvfb-run','--auto-servernum','bash','-c','openbox --sm-disable >/dev/null 2>&1 & wm=$!; trap "kill $wm" EXIT; node tools/qa/next_client_acceptance/visibility_smoke.mjs'],
        ['xvfb-run','--auto-servernum','bash','-c','openbox --sm-disable >/dev/null 2>&1 & wm=$!; trap "kill $wm" EXIT; '+PY+' -m tools.qa.next_client_acceptance.run']],
    'sfu':[[PY,'-m','unittest','tools.qa.sfu_snapshot_measure.test_identity'],
           [PY,'-m','tools.qa.sfu_snapshot_measure.run','--expect-reduction']],
}
REPORTS={
    'lifecycle':['.out/refresh-baseline/report.json','.out/client-lifecycle/1440/report.json',
                 '.out/client-lifecycle/1024/report.json','.out/upload-reservations/report.json'],
    'next':['.out/next-client-acceptance/report.json','.out/next-client-acceptance/limited.json','.out/next-client-acceptance/unlimited.json'],
    'sfu':['.out/sfu-snapshot-measure/report.json'],
}
ROOTS={'lifecycle':['.out/refresh-baseline','.out/client-lifecycle','.out/upload-reservations'],
       'next':['.out/next-client-acceptance'],'sfu':['.out/sfu-snapshot-measure']}
LIMITS={'lifecycle':1500,'next':1200,'sfu':900}
