"""Run a bounded multi-account roster journey against an owned local stack."""
import hashlib
import json
import os
import secrets
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from tools.qa.critical_client_acceptance.stack import Stack
from tools.qa.local_features.source_identity import source_identity
from tools.qa.voice_roster_multiclient.outcome import classify


def windows_path(path):
    return subprocess.check_output(['wslpath', '-m', str(path)], text=True).strip()


def main():
    root = Path(__file__).resolve().parents[3]
    base = root / '.out'
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + secrets.token_hex(4)
    destination = base / 'issue689-multiclient-roster' / stamp
    destination.mkdir(parents=True, exist_ok=False)
    before = source_identity(root)
    report = {'outcome': 'FAIL', 'source_before': before, 'actual_api': False,
              'actual_sfu': False, 'physical_device': False, 'cleanup': False}
    scenario, browser_exit = {}, -1
    with tempfile.TemporaryDirectory(prefix='issue689-roster-', dir=base) as directory:
        work = Path(directory)
        stack = Stack(root, work)
        try:
            env = dict(os.environ, VITE_PUBLIC_ORIGIN='https://localhost:4810')
            subprocess.run(['npm', 'run', 'build'], cwd=root / 'clients/web', env=env,
                           check=True, stdout=subprocess.DEVNULL)
            stack.start()
            report['actual_api'], report['actual_sfu'] = True, True
            sql = """WITH category AS (
              INSERT INTO categories (id, name, position)
              SELECT gen_random_uuid(), 'QA roster', COALESCE(MAX(position)+1,0) FROM categories
              RETURNING id
            ) INSERT INTO channels (id, category_id, name, kind, position)
              SELECT gen_random_uuid(), id, item.name, 'VOICE', item.position
              FROM category CROSS JOIN (VALUES ('QA voice', 0), ('QA voice two', 1)) AS item(name, position)"""
            subprocess.run(['docker', 'exec', stack.owner+'-db', 'psql', '-U', 'qa', '-d', 'qa',
                            '-v', 'ON_ERROR_STOP=1', '-c', sql], check=True, stdout=subprocess.DEVNULL)
            inputs, result = work / 'input.json', work / 'scenario.json'
            inputs.write_text(json.dumps({'password': stack.password, 'output': windows_path(destination)}))
            inputs.chmod(0o600)
            script = root / 'tools/qa/voice_roster_multiclient/scenario.cjs'
            with (work / 'browser.private.log').open('w') as log:
                run = subprocess.run(['/mnt/c/Windows/System32/cmd.exe', '/d', '/c', 'node', windows_path(script),
                                      windows_path(inputs), windows_path(result)], stdout=log, stderr=log, timeout=360)
            browser_exit = run.returncode
            if result.exists():
                scenario = json.loads(result.read_text())
        except Exception as error:
            report['error_type'] = type(error).__name__
        finally:
            try:
                stack.close()
                report['cleanup'] = True
            except Exception:
                report['cleanup'] = False
    try:
        after = source_identity(root)
        stable = before == after
    except Exception:
        after, stable = 'unavailable', False
    report.update(source_after=after, source_stable=stable, browser_exit=browser_exit, scenario=scenario)
    report['screenshots'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                             for path in destination.glob('*.png')}
    report['outcome'] = classify(scenario.get('checks'), browser_exit, stable, report['cleanup'])
    (destination / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('multiclient_roster='+report['outcome']+' report='+str(destination / 'report.json'), flush=True)
    return 0 if report['outcome'] == 'SMOKE_PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
