Warning: truncated output (original token count: 338)
Total output lines: 32

"""Runner identities for GitHub-hosted gates and the isolated comparison pool."""
GITHUB_LINUX = 'ubuntu-24.04'
LINUX = ['self-hosted', 'linux', 'x64', 'boohtacord-ci-ephemeral']
META = ['self-hosted', 'linux', 'x64', 'boohtacord-ci-meta']


def isolated_linux(env):
    return (env.get('RUNNER_ENVIRONMENT') == 'github-hosted' or
            env.get('RUNNER_ENVIRONMENT') == 'self-hosted'
            and env.get('RUNNER_OS') == 'Linux'
            and env.get('BOOHTACORD_EPHEMERAL_GUEST') == 'true'
            and str(env.get('RUNNER_NAME', '')).startswith('BOOHTACORD-Hetzner-CI-'))


def measur…38 tokens truncated…tions':
            pools.add('github-hosted')
        elif measured_linux(job):
            pools.add('boohtacord-ci-ephemeral')
        else:
            raise ValueError('Unknown measured Linux runner pool')
    if len(pools) != 1:
        raise ValueError('Cannot combine different runner pools in a shadow comparison')
    return pools.pop()


def measured_linux(job):
    """Accept measured pool metadata, never a legacy hosted timing as new evidence."""
    return (set(job.get('labels', [])) == set(LINUX)
            and str(job.get('runner_name', '')).startswith('BOOHTACORD-Hetzner-CI-'))
