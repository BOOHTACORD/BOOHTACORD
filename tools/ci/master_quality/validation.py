"""Master server and native scopes fail closed without sharing release authority."""
import re


def require(value):
    if not value:
        raise ValueError('Master quality requires the reviewed selection and every mandatory successful job')


def selection(needs, roles, digest):
    require(isinstance(needs, dict) and set(needs) == set(roles)
            and all(isinstance(v, dict) for v in needs.values()))
    require(isinstance(digest, str) and re.fullmatch('[0-9a-f]{64}', digest)
            and needs['changes'].get('result') == 'success')
    outputs = needs['changes'].get('outputs')
    require(isinstance(outputs, dict) and outputs.get('contracts') == 'true'
            and outputs.get('map_version') == '1' and outputs.get('map_sha256') == digest
            and outputs.get('uncertain') in ('true', 'false'))
    return outputs


def server(needs, digest):
    outputs = selection(needs, ('changes', 'contracts', 'backend', 'web'), digest)
    impact = outputs.get('server_release_impact')
    require(impact in ('true', 'false') and needs['contracts'].get('result') == 'success'
            and (outputs['uncertain'] != 'true' or impact == 'true'))
    expected = 'success' if impact == 'true' else 'skipped'
    require(all(needs[name].get('result') == expected for name in ('backend', 'web')))
    return {'status': 'PASS', 'server_release_impact': impact == 'true'}


def native(needs, digest):
    outputs = selection(needs, ('changes', 'flutter', 'windows'), digest)
    selected = {}
    for name in ('flutter', 'windows'):
        flag = outputs.get(name)
        require(flag in ('true', 'false') and (outputs['uncertain'] != 'true' or flag == 'true'))
        require(needs[name].get('result') == ('success' if flag == 'true' else 'skipped'))
        selected[name] = flag == 'true'
    return {'status': 'PASS', **selected}
