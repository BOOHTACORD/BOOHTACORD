"""Fail closed unless the common selector and every applicable gate succeeded."""
ROLES = {'changes', 'contracts', 'backend', 'web', 'flutter', 'windows', 'actual'}
COMPONENTS = ROLES - {'changes', 'contracts', 'actual'}


def require(value):
    if not value:
        raise ValueError('Required CI evidence is missing, invalid, stale, cancelled or unsuccessful')


def validate(needs, jobs, map_digest):
    require(isinstance(needs, dict) and isinstance(jobs, dict) and set(jobs) == ROLES)
    require(all(isinstance(value, str) and value for value in jobs.values()))
    require(len(set(jobs.values())) == len(jobs) and set(needs) == set(jobs.values()))
    require(all(isinstance(needs[name], dict) for name in jobs.values()))
    require(needs[jobs['changes']].get('result') == 'success')
    require(needs[jobs['contracts']].get('result') == 'success')
    outputs = needs[jobs['changes']].get('outputs')
    require(isinstance(outputs, dict) and outputs.get('contracts') == 'true')
    require(outputs.get('map_version') == '1' and outputs.get('map_sha256') == map_digest)
    require(outputs.get('uncertain') in ('true', 'false'))
    for role in COMPONENTS:
        selected = outputs.get(role)
        require(selected in ('true', 'false'))
        require(outputs['uncertain'] != 'true' or selected == 'true')
        require(needs[jobs[role]].get('result') == ('success' if selected == 'true' else 'skipped'))
    import json
    from tools.ci.actual_acceptance.plan import document,PROFILES
    require(outputs.get('actual_map_sha256') == document()[1])
    try:
        selected = json.loads(outputs['actual_profiles'])
        require(isinstance(selected, list) and selected == [p for p in PROFILES if p in selected])
        for key, allowed in [('actual_release_required','release_gates'),('actual_physical_required','physical_gates')]:
            gates = json.loads(outputs[key])
            require(isinstance(gates,list) and gates == sorted(set(gates)) and set(gates) <= set(document()[0][allowed]))
    except (KeyError, TypeError, ValueError):
        raise ValueError('Actual acceptance selection is missing or invalid') from None
    require(outputs.get('actual_required') == str(bool(selected)).lower())
    require(outputs['uncertain'] != 'true' or selected == list(PROFILES))
    require(needs[jobs['actual']].get('result') == ('success' if selected else 'skipped'))
