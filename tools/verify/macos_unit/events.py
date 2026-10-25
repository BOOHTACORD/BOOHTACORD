"""Require all eight real capture-option tests, including both Apple-only cases."""
EXPECTED = (
    'default screen options preserve baseline constraints without engine',
    'macOS capture engine preserves exact source and frame rate',
    'copyWith keeps engine independently of audio and FPS changes',
    'from constructor carries explicit engine without inventing one',
    'diagnostics default leaves native default unchanged',
    'macOS diagnostics switch preserves engine source and frame rate',
    'diagnostics copyWith preserves explicit false and independent audio policy',
    'from constructor forwards explicit diagnostics without inventing one',
)


def validate(events):
    names, completed, endings = {}, set(), []
    for row in events:
        kind = row.get('type')
        if kind == 'testStart':
            test = row['test']
            if test['id'] in names: raise ValueError('Duplicate test start')
            names[test['id']] = test['name']
        elif kind == 'testDone':
            identity = row['testID']
            if identity not in names or identity in completed or row.get('result') != 'success' or row.get('skipped'):
                raise ValueError('Failed, skipped or duplicate macOS test')
            completed.add(identity)
        elif kind == 'done': endings.append(row.get('success'))
    actual = [names[identity] for identity in completed if names[identity] in EXPECTED]
    if endings != [True] or len(actual) != len(EXPECTED) or set(actual) != set(EXPECTED):
        raise ValueError('Missing macOS capture option cases or incomplete test stream')
    return len(actual)
