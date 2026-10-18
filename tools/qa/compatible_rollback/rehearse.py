"""Observe the unchanged signed rollback command; never steer its transitions."""
import json
import os
import subprocess
import time
from storage import observe, running, sql
from evidence import validate


def exchange(work, phase, revision):
    command = {'phase': phase, 'revision': revision}
    pending = work / 'command.pending'
    pending.write_text(json.dumps(command))
    pending.replace(work / 'command.json')
    deadline = time.monotonic() + (12 if phase.endswith('_maintenance') else 45)
    while time.monotonic() < deadline:
        if (work / 'browser-failure.json').exists():
            raise RuntimeError('Actual browser observation failed')
        result = work / ('ack-' + phase + '.json')
        if result.exists():
            return json.loads(result.read_text())
        time.sleep(.1)
    raise TimeoutError('Both actual browser observers must confirm within the shipping maintenance window')


def rehearse(work):
    from tools.release.rollback.preflight import preflight
    configuration = json.loads((work / 'private/browser.json').read_text())
    current, previous = configuration['current'], configuration['previous']
    root = work / 'releases'
    os.environ['CURL_CA_BUNDLE'] = str(work / 'ca.crt')
    baseline, before = observe('baseline'), running('baseline')
    preflight(root, current, previous, work / 'trusted-signing.pub.pem')
    if observe('baseline') != baseline or running('baseline') != before:
        raise RuntimeError('Read-only preflight changed live resources')
    report = {'status': 'RUNNING', 'current': current, 'previous': previous,
              'preflight': dict.fromkeys(('read_only', 'signed_bundles', 'digest_only', 'compatible'), True),
              'observations': exchange(work, 'baseline', current), 'storage': [baseline], 'running': [before],
              'observer_seconds': 90}
    def save():
        (work / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    with (work / 'rollback-private.log').open('wb') as log:
        process = subprocess.Popen(['python3', '-m', 'tools.release.rollback.run', current, previous,
                                    '--release-root', str(root), '--public-key', str(work / 'trusted-signing.pub.pem'),
                                    '--environment', str(work / 'private/deployment.env'), '--rehearse', '--observe-seconds', '90'],
                                   cwd=work / 'current', stdout=log, stderr=subprocess.STDOUT)
        seen = set()
        deadline = time.monotonic() + 600
        try:
            while time.monotonic() < deadline:
                active = sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;') == b't'
                try:
                    state = running('probe')
                except (ValueError, KeyError, subprocess.CalledProcessError):
                    state = None
                phase, revision = None, None
                if active and 'rollback_maintenance' not in seen:
                    phase, revision = 'rollback_maintenance', current
                elif state and state['revision'] == previous and not active and 'previous' not in seen:
                    phase, revision = 'previous', previous
                elif active and 'previous' in seen and 'restore_maintenance' not in seen:
                    phase, revision = 'restore_maintenance', previous
                elif state and state['revision'] == current and not active and 'restore_maintenance' in seen and 'restored' not in seen:
                    phase, revision = 'restored', current
                if phase:
                    report['observations'].extend(exchange(work, phase, revision))
                    if phase in ('previous', 'restored'):
                        report['storage'].append(observe(phase))
                        report['running'].append(running(phase))
                    seen.add(phase)
                    save()
                if process.poll() is not None:
                    if process.returncode != 0 or 'restored' not in seen:
                        raise RuntimeError('Canonical rollback command did not complete the observed rehearsal')
                    report['status'] = 'PASS'
                    validate(report)
                    save()
                    return
                time.sleep(.2)
            raise TimeoutError('Bounded rollback rehearsal exceeded its budget')
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=120)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
