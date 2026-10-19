"""Require all actual source-bound profiles and successful prerequisite jobs."""
import math
import re
import json
from pathlib import Path
from . import catalog


def require(value):
    if not value:
        raise ValueError('Missing, foreign, partial or unsuccessful Web profile evidence')


def read_reports(directory):
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink())
    expected = {name + '.json' for name in catalog.PROFILES}
    require({path.name for path in directory.iterdir()} == expected)
    rows = []
    for name in sorted(expected):
        path = directory / name
        require(not path.is_symlink() and path.is_file() and path.stat().st_size <= 65536)
        value = json.loads(path.read_text())
        require(isinstance(value, dict) and value.get('profile') == path.stem)
        rows.append(value)
    return rows


def validate_results(source, needs, rows):
    try:
        require(isinstance(source, str) and re.fullmatch('[0-9a-f]{40}', source))
        require(set(needs) == {'fast', 'browser', 'sfu'}
                and all(value.get('result') == 'success' for value in needs.values()))
        plan = catalog.plan()
        expected = plan['profiles']
        require(isinstance(rows, list) and len(rows) == len(expected))
        seen = set()
        durations = {}
        for row in rows:
            require(set(row) == {'source_revision', 'profile', 'plan_sha256', 'status', 'operations', 'seconds', 'execution'})
            profile = row['profile']
            require(profile in expected and profile not in seen)
            require(row['source_revision'] == source and row['plan_sha256'] == catalog.digest(plan)
                    and row['status'] == 'PASS' and row['operations'] == expected[profile]
                    and row['execution'] == catalog.execution())
            seconds = row['seconds']
            require(type(seconds) in (int, float) and math.isfinite(seconds) and seconds > 0)
            seen.add(profile)
            durations[profile] = seconds
        require(seen == set(expected))
        return {'source_revision': source, 'status': 'PASS', 'profiles': sorted(seen),
                'plan_sha256': catalog.digest(plan), 'observed_profile_seconds': durations,
                'checked_operations': sum(len(value) for value in expected.values()),
                'execution': catalog.execution()}
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('Malformed Web profile or job evidence') from error
