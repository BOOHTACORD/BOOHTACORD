"""Validate explicit human attestations; this does not execute their commands."""

CATEGORIES = ('Contracts', 'Traceability', 'Evidence', 'Generated', 'Dependencies', 'Client checks')


def decision(report, review):
    if not isinstance(review, dict) or review.get('fingerprint') != report['fingerprint']:
        return 'COMMIT_BLOCKED'
    client = report.get('client_registry_check', {})
    unavailable_client = client.get('status') == 'BLOCKED' and not client.get('unknown_paths')
    if (report.get('scope_changed_during_check') or report['diff_check'] != 'PASS' or report['unexpected_or_sensitive_paths']
            or any(v['status'] != 'PASS' for v in report['generated_checks'].values())
            or any(v['status'] not in ('PASS', 'N/A') for v in report.get('related_checks', {}).values())
            or client.get('status') == 'FAIL' or unavailable_client):
        return 'COMMIT_BLOCKED'
    checks = review.get('checks')
    if not isinstance(checks, dict):
        return 'COMMIT_BLOCKED'
    if report['dependency_review'].startswith('BLOCKED'):
        dependency = checks.get('Dependencies')
        if not isinstance(dependency, dict) or dependency.get('status') != 'PASS':
            return 'COMMIT_BLOCKED'
    required = {f'gate:{gate}' for gate in report['selection']['gates'] if gate != 'server'}
    required.update(f'actual:{profile}' for profile in report['actual_acceptance']['profiles'])
    required.add('Contracts')
    inventory = report.get('inventory', {})
    if inventory.get('staged') and (inventory.get('unstaged') or inventory.get('untracked')):
        required.add('Staging')
    for key in set(CATEGORIES) | required:
        value = checks.get(key)
        if not isinstance(value, dict) or value.get('status') not in ('PASS', 'N/A', 'BLOCKED'):
            return 'COMMIT_BLOCKED'
        pending_ci = (key.startswith(('gate:', 'actual:')) and value['status'] == 'BLOCKED'
                      and value.get('scope') == 'hosted_ci')
        if value['status'] == 'BLOCKED' and not pending_ci:
            return 'COMMIT_BLOCKED'
        if key in required and value['status'] != 'PASS' and not pending_ci:
            return 'COMMIT_BLOCKED'
        if not isinstance(value.get('reason'), str) or not value['reason'].strip():
            return 'COMMIT_BLOCKED'
        if value['status'] in ('PASS', 'BLOCKED') and (not isinstance(value.get('command'), str) or not value['command'].strip()):
            return 'COMMIT_BLOCKED'
    return 'COMMIT_ALLOWED'
