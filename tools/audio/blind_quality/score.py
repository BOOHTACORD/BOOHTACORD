"""Count complete blinded votes; never infer acoustic or release acceptance."""
from collections import defaultdict


def empty_counts():
    return {'new': 0, 'old': 0, 'tie': 0, 'speech_defect_yes': 0, 'total': 0}


def summarize(plan, votes):
    by_id = {item['trial']: item for item in plan}
    if not plan or len(by_id) != len(plan):
        raise ValueError('Duplicate or empty plan')
    listeners = {item['listener'] for item in plan}
    if len(listeners) < 10 or len(listeners) % 2:
        raise ValueError('At least ten balanced listeners are required')
    groups = defaultdict(list)
    for item in plan:
        candidate = item['candidate']
        if candidate == 'v01' or {item['first'], item['second']} != {'v01', candidate}:
            raise ValueError('Invalid paired order')
        groups[(item['scenario'], candidate)].append(item)
    scenarios = {item['scenario'] for item in plan}
    candidates = {item['candidate'] for item in plan}
    if set(groups) != {(scenario, candidate) for scenario in scenarios for candidate in candidates}:
        raise ValueError('Missing model-scenario pair')
    for group in groups.values():
        if (len(group) != len(listeners) or {item['listener'] for item in group} != listeners
                or sum(item['first'] == 'v01' for item in group) * 2 != len(listeners)):
            raise ValueError('Incomplete or unbalanced plan')
    responses = {}
    for vote in votes:
        trial = vote.get('trial')
        if (trial not in by_id or trial in responses or vote.get('preferred') not in ('A', 'B', 'tie')
                or vote.get('speech_defect') not in ('yes', 'no', 'unsure')):
            raise ValueError('Invalid or duplicate response')
        responses[trial] = vote
    if set(responses) != set(by_id):
        raise ValueError('Incomplete responses')
    result = defaultdict(empty_counts)
    conditions = defaultdict(lambda: defaultdict(empty_counts))
    for trial, item in by_id.items():
        vote = responses[trial]
        chosen = {'A': item['first'], 'B': item['second'], 'tie': 'tie'}[vote['preferred']]
        for group in (result[item['candidate']], conditions[item['candidate']][item['scenario']]):
            group['tie' if chosen == 'tie' else 'old' if chosen == 'v01' else 'new'] += 1
            group['speech_defect_yes'] += vote['speech_defect'] == 'yes'
            group['total'] += 1
    return {'acceptance': 'NOT_ASSESSED', 'models': dict(result),
            'conditions': {candidate: dict(items) for candidate, items in conditions.items()}}
