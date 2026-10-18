"""Fail closed unless the common selector and every applicable gate succeeded."""
ROLES = {'changes', 'contracts', 'backend', 'web', 'flutter', 'windows'}
COMPONENTS = ROLES - {'changes', 'contracts'}


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
