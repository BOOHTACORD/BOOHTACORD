"""Keep release/acceptance proof durable; shorten only successful PR review captures."""
ROLES = frozenset(('release-proof', 'release-bundle', 'native-package', 'acceptance',
                   'failure-diagnostics', 'synthetic-captures'))
CAPTURE_EXPRESSION = "${{ github.event_name == 'pull_request' && startsWith(github.ref, 'refs/pull/') && job.status == 'success' && 7 || 30 }}"


def days(role, event, ref, status):
    if role not in ROLES:
        raise ValueError('Unknown artifact retention class')
    short = (role == 'synthetic-captures' and event == 'pull_request'
             and isinstance(ref, str) and ref.startswith('refs/pull/') and status == 'success')
    return 7 if short else 30
