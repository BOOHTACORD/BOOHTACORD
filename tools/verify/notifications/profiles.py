"""Native commands for local notification checks; no external provider calls."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]

def execute(profile, run, promtool):
    backend, web, flutter = (ROOT / p for p in ('backend','clients/web','clients/flutter'))
    if profile == 'backend':
        run(['go','run','./cmd/check-test-database'], backend)
        events = ROOT / '.out/notification-acceptance/backend.jsonl'
        with events.open('w', encoding='utf-8') as stream:
            result = subprocess.run(['go','test','-json','-count=1','./...'],cwd=backend,stdout=stream,stderr=subprocess.STDOUT)
        run([sys.executable,'tools/verify/go_test_events/verify-go-test-events.py',str(events)],ROOT)
        result.check_returncode()
        run(['go','vet','./...'],backend)
        run(['go','build','./...'],backend)
    elif profile == 'contracts':
        run([sys.executable,'-m','unittest','tools.verify.openapi_parity.test_parity','tools.verify.openapi_parity.test_source','tools.verify.notifications.test_contracts','tools.ci.select_changes.test_notification_routing','tools.ci.web_suites.test_catalog'],ROOT)
        run([sys.executable,'-m','tools.verify.openapi_parity.lint'],ROOT)
        run([sys.executable,'-m','tools.verify.openapi_parity.validate'],ROOT)
    elif profile == 'web':
        for command in (['npm','test','--','--run'],['npm','run','build'],['npm','run','test:notifications']):run(command,web)
    elif profile == 'flutter':
        run(['flutter','test','--no-pub'],flutter)
        run(['flutter','analyze','--no-pub','--no-fatal-infos'],flutter)
        for name in ('server_policy','relay_signature','server_preferences'):
            run(['dart','run','test/notifications/'+name+'_conformance.dart'],flutter)
    elif profile == 'flutter-vendor':
        from tools.ci.flutter_setup.vendor_locks import prepare
        for package in ('livekit_client','flutter_webrtc'):
            prepare(ROOT,package)
            directory=flutter/'packages'/package
            run(['flutter','pub','get','--enforce-lockfile'],directory)
            run(['flutter','test','--no-pub'],directory)
    elif profile == 'queries':
        if not promtool:raise FileNotFoundError('Pinned promtool3.11.2 is required for actual query evaluation')
        run([promtool,'test','rules','tools/verify/notifications/dashboard.test.yaml','tools/verify/notifications/queries.test.yaml'],ROOT)
    else:raise ValueError('Unknown local notification profile')
