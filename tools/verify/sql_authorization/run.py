"""Execute real PostgreSQL authorization tests; kill audited mutations in a copy."""
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CASES = (
    ('chat/edit_text_message', 'repository.go', 'AND message.author_id = $3',
     'AND (message.author_id = $3 OR TRUE)', 'TestPostgresEditAuthorization/foreign_author'),
    ('storage/authorize_direct_message_attachment', 'repository.go',
     'AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)',
     'AND ($1::uuid IN (dm.participant_one_id, dm.participant_two_id) OR TRUE)',
     'TestPostgresAttachmentPairAuthorization/outsider_administrator'),
    ('media/publish_screen_descriptor', 'statements.go', 'session.revoked_at IS NULL',
     '(session.revoked_at IS NULL OR TRUE)', 'TestPostgresDescriptorAdmission/revoked_session'),
)
SCENARIOS = {
    'TestPostgresEditAuthorization': ('author', 'foreign_author', 'stale_revision',
        'archived_channel', 'wrong_channel', 'voice_channel', 'deleted_message'),
    'TestPostgresAttachmentPairAuthorization': ('first', 'second', 'outsider',
        'outsider_administrator', 'blocked_first', 'blocked_second', 'missing_pair'),
    'TestPostgresDescriptorAdmission': ('active', 'revoked_session', 'revoked_lease',
        'closed_channel', 'archived_channel', 'text_channel', 'blocked_account', 'foreign_account', 'foreign_session'),
}


def execute(backend, packages, log):
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run(['go', 'test', '-json', '-count=1', *packages], cwd=backend, stdout=stream)
    events = [json.loads(line) for line in log.read_text(encoding='utf-8').splitlines()]
    passed = {e['Test'] for e in events if e.get('Test') and e.get('Action') == 'pass'}
    failed = {e['Test'] for e in events if e.get('Test') and e.get('Action') == 'fail'}
    skipped = {e['Test'] for e in events if e.get('Test') and e.get('Action') == 'skip'}
    return result.returncode, passed, failed, skipped


def main():
    out = ROOT / '.out/checks/sql-authorization'
    out.mkdir(parents=True, exist_ok=True)
    report = {'status': 'FAIL', 'source_revision': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'mutations': []}
    report['source_dirty'] = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True))
    report['test_source_sha256'] = {str(p.relative_to(ROOT)).replace('\\', '/'):
        hashlib.sha256(p.read_bytes()).hexdigest() for row in CASES
        for p in sorted((ROOT / 'backend/internal' / row[0] / 'postgres').glob('*_test.go'))}
    path = out / 'result.json'
    path.write_text(json.dumps(report) + '\n')
    try:
        with tempfile.TemporaryDirectory(prefix='boohta-sql-') as temporary:
            backend = Path(temporary) / 'backend'
            shutil.copytree(ROOT / 'backend', backend, ignore=shutil.ignore_patterns('.out', '*.exe'))
            packages = ['./internal/' + row[0] + '/postgres' for row in CASES]
            code, passed, failed, skipped = execute(backend, packages, out / 'baseline.jsonl')
            required = {parent + '/' + name for parent, names in SCENARIOS.items() for name in names}
            if code or failed or skipped or not required <= passed:
                raise RuntimeError('Baseline must execute every authorization suite without skips')
            report.update(baseline_passed=len(passed), required_scenarios=sorted(required))
            for index, (leaf, name, old, new, witness) in enumerate(CASES):
                source = backend / 'internal' / leaf / 'postgres' / name
                original = source.read_bytes()
                if original.count(old.encode()) != 1:
                    raise RuntimeError('Audited predicate no longer has one exact mutation site')
                source.write_bytes(original.replace(old.encode(), new.encode()))
                try:
                    code, _, failed, skipped = execute(backend, [packages[index]], out / f'mutation-{index + 1}.jsonl')
                    if code == 0 or witness not in failed or skipped:
                        raise RuntimeError('Mutation survived or failed without its authorization counterexample')
                    report['mutations'].append({'file': str(source.relative_to(backend)).replace('\\', '/'),
                        'original_sha256': hashlib.sha256(original).hexdigest(), 'old': old, 'new': new,
                        'witness': witness, 'failed_tests': sorted(failed), 'exit_code': code, 'status': 'KILLED'})
                finally:
                    source.write_bytes(original)
            code, passed, failed, skipped = execute(backend, packages, out / 'restored.jsonl')
            if code or failed or skipped or not required <= passed:
                raise RuntimeError('Restored source failed baseline')
            for leaf, name, *_ in CASES:
                if (ROOT / 'backend/internal' / leaf / 'postgres' / name).read_bytes() != (backend / 'internal' / leaf / 'postgres' / name).read_bytes():
                    raise RuntimeError('Repository source changed during isolated mutation run')
            report.update(status='PASS', restored_passed=len(passed), skipped=0)
    finally:
        path.write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: three PostgreSQL mutations killed; baseline/restored suites have no skips')


if __name__ == '__main__':
    main()
