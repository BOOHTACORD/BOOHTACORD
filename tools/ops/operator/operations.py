"""Fixed observed capabilities; only explicitly approved mutation plans can change a host."""
import hashlib
from pathlib import Path
import secrets
from urllib.request import urlopen
from .policy import require

ROOT=Path(__file__).resolve().parents[3]
BUILDX_SHA='9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b'
BUILDX_URL='https://github.com/docker/buildx/releases/download/v0.37.1/buildx-v0.37.1.linux-amd64'


def current(ssh,source):
    raw=ssh.script(ROOT/'tools/release/delivery/current_revision.sh',[],30,root=True)
    require(raw.decode().strip()==source)


def perform(plan,ssh,private,*,audit=None):
    operation=plan['operation'];source=plan['expected_source']
    if plan['risk']=='read-only':
        command='boohtacord-operator-v1 '+operation+' '+source
        if operation=='sample':command+=' '+str(plan['sample_count'])
        require(ssh.command(command,plan['timeout'])==('boohtacord-operator-v1 PASS '+source+'\n').encode())
        return
    current(ssh,source)
    if operation=='rollback':
        previous=plan['previous_source']
        command=('sudo -n env PYTHONPATH=/opt/voice-platform-releases/'+source+
                 ' python3 -m tools.release.rollback.run '+source+' '+previous+' --rehearse --observe-seconds 30')
        raw=ssh.command(command,plan['timeout'])
        require(('Verified rollback completed; running '+source).encode() in raw)
    else:
        require(operation=='probe')
        binary=Path(private)/'docker-buildx';digest=hashlib.sha256();size=0
        with urlopen(BUILDX_URL,timeout=30) as response,binary.open('xb') as stream:
            binary.chmod(0o600)
            while block:=response.read(65536):
                size+=len(block);require(size<=256_000_000);digest.update(block);stream.write(block)
        require(size>0 and digest.hexdigest()==BUILDX_SHA)
        namespace=secrets.token_hex(8);incoming='/tmp/voice-platform-qa11-buildx-'+source+'-'+namespace
        if audit is not None:audit.update(owned_namespace=namespace,host_cleanup='NOT_VERIFIED')
        try:
            ssh.copy(binary,incoming)
            raw=ssh.script(ROOT/'tools/build/legacy_server/probe_buildx.sh',[incoming],plan['timeout'],root=True)
            require(all(marker in raw for marker in (b'operator_probe_cleanup=PASS\n',
                    b'default_driver_oci_export=yes\n',b'default_driver_dual_export=yes\n',b'compose_local_digest_ref=yes\n')))
        finally:
            # Scoped exact file only; the remote script cleans its own objects.
            # Also covers a dropped scp connection before the script started.
            ssh.command('rm -f -- '+incoming,20)
        if audit is not None:audit['host_cleanup']='PASS'
    current(ssh,source)
