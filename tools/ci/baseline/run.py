"""python -m tools.ci.baseline.run --help (read-only; no workflow mutations)."""
import argparse
import hashlib
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
from .api import Api
from .collect import COHORTS, collect_run, sample
from .report import build_report, compact_run


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True, help='Local sanitized collection, outside committed evidence')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ci-samples', type=int, default=30)
    parser.add_argument('--delivery-samples', type=int, default=5)
    parser.add_argument('--native-samples', type=int, default=3)
    parser.add_argument('--max-requests', type=int, default=1000)
    parser.add_argument('--offline', action='store_true', help='Recompute only; fail if any frozen sample is incomplete')
    args = parser.parse_args()
    counts = {c: args.ci_samples if c.startswith('ci_') else args.delivery_samples
              if c in ('server_build', 'deploy') else args.native_samples for c in COHORTS}
    if any(not 1 <= n <= 100 for n in counts.values()):
        parser.error('Each sample limit must be between 1 and 100')
    repository = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip())
    policy = {'sample_limits': counts, 'repository': 'BOOHTACORD/BOOHTACORD', 'schema_version': 1}
    manifest = args.cache / 'manifest.json'
    if manifest.exists():
        metadata = json.loads(manifest.read_text())
        if any(metadata.get(k) != v for k, v in policy.items()):
            parser.error('Cache policy differs; choose a new cache directory')
    elif args.offline:
        parser.error('Offline cache manifest is missing')
    else:
        metadata = {**policy, 'started_at': datetime.now(timezone.utc).isoformat(),
                    'collector_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()}
        write(manifest, metadata)
    api, cohorts = Api(max_requests=args.max_requests), {}
    for cohort, count in counts.items():
        listing = args.cache / (cohort + '-sample.json')
        if not listing.exists():
            if args.offline:
                raise RuntimeError('Incomplete frozen sample: ' + cohort)
            # Store allowlisted listings only, while preserving master classification.
            from .normalize import normalize_run
            selected = [normalize_run(r) for r in sample(api, cohort, count)]
            write(listing, selected)
        rows = []
        for raw in json.loads(listing.read_text()):
            cached = args.cache / 'runs' / (str(raw['id']) + '.json')
            if not cached.exists():
                if args.offline:
                    raise RuntimeError('Missing cached run: ' + str(raw['id']))
                run = collect_run(api, raw, repository, cohort == 'server_build')
                run['ref_kind'] = raw['ref_kind']
                write(cached, run)
                print(f'{cohort}: collected run {raw["id"]} (requests {api.requests})', flush=True)
            rows.append(json.loads(cached.read_text()))
        cohorts[cohort] = rows
    if not metadata.get('completed_at'):
        if args.offline:
            raise RuntimeError('Collection completion receipt is missing')
        metadata['completed_at'] = datetime.now(timezone.utc).isoformat()
        write(manifest, metadata)
    report = build_report(cohorts)
    report['collection'] = metadata
    sources = sorted((repository / 'tools/ci/baseline').glob('*.py'))
    sources.append(repository / 'tools/ci/select_changes/selection.py')
    report['analysis_tool_sha256'] = {str(p.relative_to(repository)): hashlib.sha256(p.read_bytes()).hexdigest()
                                      for p in sources}
    for cohort, rows in cohorts.items():
        write(args.output / (cohort + '.json'), [compact_run(r) for r in rows])
    write(args.output / 'summary.json', report)
    print('Complete read-only metadata baseline: ' + str(args.output))


if __name__ == '__main__':
    main()
