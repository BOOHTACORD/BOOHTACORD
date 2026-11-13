"""Create balanced paired-listening assignments, not listening results."""
import hashlib
import random
import re


def paired_trials(scenarios, candidates, listener_count, rng=None):
    labels = [*scenarios, *candidates]
    if (not scenarios or not candidates or len(scenarios) > 40 or len(candidates) > 2
            or len(set(scenarios)) != len(scenarios) or len(set(candidates)) != len(candidates)
            or 'v01' in candidates or not all(isinstance(x, str) and re.fullmatch(r'[a-z0-9_-]{1,40}', x) for x in labels)
            or not isinstance(listener_count, int) or listener_count < 10 or listener_count > 100 or listener_count % 2):
        raise ValueError('Require unique condition IDs, candidates and 10-100 even listeners')
    rng = rng or random.SystemRandom()
    salt = rng.getrandbits(128).to_bytes(16, 'big')
    trials = []
    for scenario in scenarios:
        for candidate in candidates:
            order = ['v01'] * (listener_count // 2) + [candidate] * (listener_count // 2)
            rng.shuffle(order)
            for index, first in enumerate(order):
                opaque = hashlib.sha256(salt + len(trials).to_bytes(8, 'big')).hexdigest()[:24]
                trials.append({'trial': opaque, 'listener': index + 1, 'scenario': scenario,
                               'candidate': candidate, 'first': first,
                               'second': candidate if first == 'v01' else 'v01'})
    rng.shuffle(trials)
    return trials


def listener_sheet(assignments, listener):
    return [{'trial': trial['trial'], 'preferred': '', 'speech_defect': ''}
            for trial in assignments if trial['listener'] == listener]
