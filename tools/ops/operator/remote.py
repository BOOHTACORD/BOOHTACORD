"""Root-owned forced-command entrypoint for the separate read-only diagnostic SSH key."""
import os
from pathlib import Path
import sys
import time

ROOT=Path(__file__).resolve().parents[3]
def trusted_source():
    for relative in ('tools/ops/operator/remote.py','tools/ops/operator/policy.py','tools/release/delivery/commands.py',
                     'tools/release/delivery/current_revision.sh','tools/release/preflight/preflight.sh',
                     'tools/ops/attachment_audit/audit-attachment-volume.sh'):
        for entry in (ROOT/relative,*(ROOT/relative).parents):
            if entry.is_symlink() or entry.stat().st_uid!=0 or entry.stat().st_mode & 0o022:
                raise ValueError('Untrusted diagnostic installation')


if __name__=='__main__':
    try:
        if not sys.flags.isolated or not sys.dont_write_bytecode:raise ValueError('Isolated interpreter required')
        trusted_source()
    except Exception:
        print('Untrusted diagnostic installation',file=sys.stderr);raise SystemExit(1)

sys.path.insert(0,str(ROOT))
from tools.ops.operator.policy import require,remote_request
from tools.release.delivery.commands import execute


def invoke(relative,*args,timeout=20):
    return execute(['sudo','-n','bash',str(ROOT/relative),*args],timeout,capture_limit=65536)


def observe(operation,source,count):
    require(invoke('tools/release/delivery/current_revision.sh').decode().strip()==source)
    if operation=='preflight':invoke('tools/release/preflight/preflight.sh',timeout=60)
    elif operation=='audit':invoke('tools/ops/attachment_audit/audit-attachment-volume.sh',source)
    else:
        active=0;released=False;peak=0;deadline=time.monotonic()+225
        for index in range(count):
            require(time.monotonic()<deadline)
            raw=invoke('tools/ops/attachment_audit/audit-attachment-volume.sh',source).decode()
            fields=[line.split('=',1)[1] for line in raw.splitlines() if line.startswith('reserved_bytes=')]
            require(len(fields)==1 and fields[0].isdigit());reserved=int(fields[0])
            if reserved>0:active+=1;peak=max(peak,reserved)
            elif active:released=True
            if index<count-1:time.sleep(1)
        require(active>=2 and peak>=25_000_000 and released)
    require(invoke('tools/release/delivery/current_revision.sh').decode().strip()==source)
    return 'boohtacord-operator-v1 PASS '+source+'\n'


def main():
    try:
        operation,source,count=remote_request(os.environ.get('SSH_ORIGINAL_COMMAND',''))
        # No client-supplied code, paths, Python environment, commands or metrics
        # leave this capability boundary. Install all dependencies root-owned.
        os.environ.clear();os.environ.update(PATH='/usr/sbin:/usr/bin:/sbin:/bin',LC_ALL='C',HOME='/nonexistent')
        print(observe(operation,source,count),end='')
    except BaseException:
        print('Operator diagnostic refused or failed',file=sys.stderr);return 1
    return 0


if __name__=='__main__':raise SystemExit(main())
