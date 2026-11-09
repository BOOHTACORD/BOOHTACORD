"""Run one bounded roster comparison cell on a newly owned local fixture."""
import argparse
import hashlib
import json
import os
import platform
import secrets
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from tools.load.controller.artifact_identity import api_binary_sha256
from tools.load.controller.cleanup import cleanup
from tools.load.guard.server import Guard
from tools.load.provision.dataset import provision, roster_room_count
from tools.load.provision.stack import Stack
from tools.load.roster_matrix.outcome import classify
from tools.load.roster_matrix.public_outcome import classify_public
from tools.load.roster_matrix.profile import scope
from tools.load.roster_matrix.source import source_identity
from tools.qa.client_lifecycle.services import ports_available, run

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--mode', choices=('baseline', 'candidate'), required=True)
    parser.add_argument('--accounts', type=int, required=True)
    parser.add_argument('--rooms', type=int, required=True)
    parser.add_argument('--seconds', type=int, default=120)
    parser.add_argument('--guests', type=int, default=0)
    parser.add_argument('--same-source', action='store_true')
    parser.add_argument('--maintenance-change', action='store_true')
    parser.add_argument('--messages', type=int, default=0)
    parser.add_argument('--message-warmup-ms', type=int, default=0)
    parser.add_argument('--allow-dirty-smoke', action='store_true')
    args = parser.parse_args()
    roster_room_count(args.accounts, args.rooms)
    if not 0 <= args.guests <= 100 or (args.guests and (args.accounts != 1 or args.rooms != 0)):
        raise ValueError('Public profile requires 1..100 guests, one fixture account and zero rooms')
    if args.same_source and (args.guests or args.accounts != 20):
        raise ValueError('Shared-source profile requires exactly 20 authenticated accounts')
    if args.maintenance_change and args.guests:
        raise ValueError('Maintenance change profile requires authenticated actors')
    if not 0 <= args.messages <= 20 or (args.messages and args.guests):
        raise ValueError('Message profile requires 1..20 messages and authenticated actors')
    if not 0 <= args.message_warmup_ms <= 2000 or (args.message_warmup_ms and not args.messages):
        raise ValueError('Warmup requires messages and must be at most 2000 ms')
    if not 20 <= args.seconds <= 600 or platform.system() != 'Linux':
        raise ValueError('Cell requires Linux and a 20..600 second budget')
    driver_root = Path(__file__).resolve().parents[3]
    source = args.source.resolve()
    source_sha, source_clean = source_identity(source, args.allow_dirty_smoke)
    driver_sha, driver_clean = source_identity(driver_root, args.allow_dirty_smoke)
    immutable = source_clean and driver_clean
    output_root = driver_root / '.out/roster-matrix'
    output_root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + secrets.token_hex(4)
    label = f'public-{args.guests}' if args.guests else f'{args.accounts}-{args.rooms}' + ('-shared' if args.same_source else '') + ('-change' if args.maintenance_change else '')
    destination = output_root / f'{args.mode}-{label}-{stamp}'
    destination.mkdir()
    ports_available((4890,))
    report = dict(outcome='FAIL', scope=scope(args.guests, args.maintenance_change, args.messages, args.message_warmup_ms),
                  target_capacity='NOT_RUN', immutable=immutable, source_revision=source_sha,
                  driver_revision=driver_sha, source_clean=source_clean, driver_clean=driver_clean)
    with tempfile.TemporaryDirectory(prefix='roster-matrix-', dir=driver_root / '.out') as directory:
        stack, guard, stage = Stack(source, Path(directory)), None, 'fixture_start'
        try:
            stack.start()
            stage = 'synthetic_provision'
            nonce = secrets.token_hex(32)
            dataset = provision(stack, nonce, args.accounts, rooms=args.rooms)
            manifest = dict(Origin='https://localhost:4810', Guard='http://127.0.0.1:4890',
                            Dataset='qa', Nonce=nonce, Owner=stack.owner, Commit=source_sha,
                            UploadBytes=1024, MaxRequests=100000, MaxSeconds=args.seconds, **dataset)
            guard = Guard(stack, manifest)
            guard.start()
            stage = 'driver_build'
            binary = Path(directory) / 'roster-matrix'
            run('go', 'build', '-o', str(binary), './cmd/roster-matrix', cwd=driver_root / 'backend')
            report['driver_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
            report['api_sha256'] = api_binary_sha256(stack, directory)
            stage = 'driver_execute'
            command = [str(binary), '--mode', args.mode] + (['--guests', str(args.guests)] if args.guests else [])
            if args.same_source:
                command.append('--same-source')
            if args.maintenance_change:
                command.append('--maintenance-change')
            if args.messages:
                command.extend(['--messages', str(args.messages)])
            if args.message_warmup_ms:
                command.extend(['--message-warmup-ms', str(args.message_warmup_ms)])
            completed = subprocess.run(command, input=json.dumps(manifest),
                                       text=True, capture_output=True, timeout=args.seconds + 30)
            driver = json.loads(completed.stdout)
            report['driver'] = driver
            report['outcome'] = (classify_public(driver, completed.returncode, args.mode, args.guests, immutable)
                                 if args.guests else classify(driver, completed.returncode, args.mode, args.accounts, args.rooms, immutable, args.same_source, args.maintenance_change, args.messages, args.message_warmup_ms))
            if (source_identity(source, True) != (source_sha, source_clean)
                    or source_identity(driver_root, True) != (driver_sha, driver_clean)):
                report.update(outcome='FAIL', failure_stage='source_changed')
            report['inventory'] = dict(os=platform.platform(), cpus=os.cpu_count(),
                                       ram_bytes=os.sysconf('SC_PHYS_PAGES') * os.sysconf('SC_PAGE_SIZE'),
                                       postgres='17.6', sfu='1.13.7', network='loopback; media NOT_RUN')
        except Exception:
            report.update(outcome='FAIL', failure_stage=stage)
        finally:
            try:
                if guard:
                    guard.close()
            except Exception:
                report.update(outcome='FAIL', failure_stage='guard_cleanup')
            report.update(cleanup(stack))
            if report['cleanup_failures'] or not report['owned_resources_removed']:
                report.update(outcome='FAIL', failure_stage='owned_resource_cleanup')
            (destination / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Roster fixture result ' + report['outcome'] + '; report=' + str(destination / 'report.json'))
    return 0 if report['outcome'] in ('PASS', 'SMOKE_PASS') else 1
if __name__ == '__main__':
    raise SystemExit(main())
