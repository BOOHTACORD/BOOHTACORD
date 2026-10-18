"""The shipping fixed project name is safe only inside the owned nested daemon."""
import re

LABEL = 'boohtacord.qa.rollback'


def egress_name(owner):
    require_owner({LABEL: owner}, owner)
    return owner + '-sfu-egress'


def ownership_arguments(uid, gid, names):
    if any(type(value) is not int or value < 0 for value in (uid, gid)):
        raise ValueError('Numeric caller ownership is required')
    if any(not re.fullmatch('[A-Za-z0-9][A-Za-z0-9._-]*', name) or name in ('.', '..') for name in names):
        raise ValueError('Only direct owned work entries may change ownership')
    paths = ['/qa/' + name for name in names if name not in ('current', 'previous')]
    if not paths:
        return []
    # Preserve the two caller-owned source checkouts; do not dereference links
    # in generated artifacts into shared Git objects or any other host path.
    return ['chown', '--recursive', '--no-dereference', '--preserve-root', '-P', str(uid) + ':' + str(gid), *paths]


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
