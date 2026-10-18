"""The shipping fixed project name is safe only inside the owned nested daemon."""
import re

LABEL = 'boohtacord.qa.rollback'


def require_amd64_daemon(info):
    if info.get('Architecture') not in ('amd64', 'x86_64'):
        raise ValueError('Use an isolated Linux amd64 Docker VM; Rosetta server builds are not accepted')


def daemon_arguments(owner):
    require_owner({LABEL: owner}, owner)
    # A flag as argv[0] makes docker:dind's entrypoint add an unauthenticated
    # TCP listener even when --host=unix is supplied later. Keep its setup but
    # pass the daemon name explicitly to avoid those defaults.
    return ['dockerd', '--host=unix:///var/run/docker.sock',
            '--label=' + LABEL + '=' + owner, '--feature=containerd-snapshotter=true']


def require_owner(labels, owner):
    if not re.fullmatch(r'qa60-[0-9a-f]{16}', owner) or labels.get(LABEL) != owner:
        raise ValueError('Refusing unowned rollback resource')


def require_owned_daemon(info, objects, owner):
    require_owner(dict(item.split('=', 1) for item in info.get('Labels', []) if '=' in item), owner)
    if objects:
        raise ValueError('Dedicated rollback daemon must initially be empty')
