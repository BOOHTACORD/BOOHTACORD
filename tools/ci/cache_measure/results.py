"""Validate comparable cold/warm observations without converting misses to PASS."""
import json
import math


def summarize(rows):
    if (len(rows) != 4 or {(r.get('pair'), r.get('temperature')) for r in rows}
            != {(p, t) for p in (1, 2) for t in ('cold', 'warm')}):
        raise ValueError('Two complete independent cold/warm pairs required')
    tests = rows[0].get('tests')
    if (not isinstance(tests, list) or not tests or tests != sorted(set(tests))
            or any(not isinstance(t, str) or not t for t in tests)):
        raise ValueError('Actual nonempty test identities required')
    for row in rows:
        seconds = row.get('seconds')
        if (row.get('status') != 'PASS' or row.get('tests') != tests
                or type(seconds) not in (float, int) or not math.isfinite(seconds) or seconds <= 0):
            raise ValueError('Failed, skipped, invalid or incomparable observations')
    def stats(temperature):
        values = sorted(r['seconds'] for r in rows if r['temperature'] == temperature)
        return {'n': len(values), 'p50_seconds': values[0], 'p95_seconds': values[-1]}
    return {'cold': stats('cold'), 'warm': stats('warm'), 'tests': tests,
            'percentiles': 'nearest-rank; n=2 descriptive microbenchmark, not CI latency SLO'}


def go_tests(text):
    events = [json.loads(line) for line in text.splitlines() if line.strip()]
    if (not events or any(e.get('Action') in ('fail', 'skip') or '(cached)' in e.get('Output', '') for e in events)
            or not any(e.get('Action') == 'pass' and not e.get('Test') for e in events)):
        raise ValueError('Go assertions must actually execute, uncached and without skips')
    tests = [e['Test'] for e in events if e.get('Action') == 'pass' and e.get('Test')]
    if not tests or len(tests) != len(set(tests)):
        raise ValueError('Missing or duplicate Go assertions')
    return sorted(tests)


def vitest_tests(value):
    if (value.get('success') is not True or value.get('numFailedTests') != 0
            or value.get('numPendingTests') != 0 or value.get('numTodoTests') != 0
            or value.get('numPassedTests') != value.get('numTotalTests')):
        raise ValueError('Every selected Vitest assertion must execute successfully')
    tests = [a['fullName'] for f in value.get('testResults', []) for a in f.get('assertionResults', [])
             if a.get('status') == 'passed']
    if not tests or len(tests) != len(set(tests)) or len(tests) != value.get('numTotalTests'):
        raise ValueError('Missing, duplicate or skipped Vitest assertions')
    return sorted(tests)
