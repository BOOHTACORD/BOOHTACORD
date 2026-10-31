"""Only a clean exact upstream master execution can attest master quality."""
import re


def validate(env, actual_source, clean):
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('GITHUB_REPOSITORY') != 'BOOHTACORD/BOOHTACORD'
            or env.get('GITHUB_REF') != 'refs/heads/master'
            or env.get('GITHUB_EVENT_NAME') not in ('push', 'workflow_dispatch')
            or not re.fullmatch('[0-9a-f]{40}', env.get('GITHUB_SHA', ''))
            or env.get('GITHUB_SHA') != actual_source or clean is not True
            or not re.fullmatch('[1-9][0-9]{0,19}', env.get('GITHUB_RUN_ID', ''))
            or not re.fullmatch('[1-9][0-9]{0,3}', env.get('GITHUB_RUN_ATTEMPT', ''))):
        raise ValueError('Exact clean upstream master source and execution required')
    return {'source_revision': actual_source, 'run_id': env['GITHUB_RUN_ID'],
            'run_attempt': env['GITHUB_RUN_ATTEMPT']}
