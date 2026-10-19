"""Provision ephemeral QA trust and real loopback SSH only inside the owned daemon."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time
from tools.qa.compatible_rollback.isolation import require_owner, require_amd64_daemon


def require_scope(work, owner, info, *, platform=sys.platform, uid=None):
    uid=os.geteuid() if uid is None else uid
    if work!=Path('/qa') or platform!='linux' or uid!=0:
        raise ValueError('QA provisioning requires its owned Linux controller')
    require_amd64_daemon(info)
    require_owner(dict(v.split('=',1) for v in info.get('Labels',[]) if '=' in v),owner)


def configuration():
    return '''Port 22
ListenAddress 127.0.0.1
HostKey /qa/private/sshd_ed25519
PidFile /qa/private/sshd.pid
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
UsePAM no
AllowUsers operator
AuthorizedKeysFile .ssh/authorized_keys
Subsystem sftp internal-sftp
'''


def start(work):
    work=Path(work)
    info=json.loads(subprocess.check_output(['docker','info','--format','{{json .}}']))
    require_scope(work,(work/'owner').read_text(),info)
    import pwd
    def run(*args): subprocess.run(args,check=True,capture_output=True)
    private=work/'private'
    client=private/'client'; (client/'.ssh').mkdir(mode=0o700,parents=True,exist_ok=False)
    host_key=private/'sshd_ed25519'; client_key=client/'.ssh/id_deploy'
    for path in (host_key,client_key):
        run('ssh-keygen','-t','ed25519','-N','','-f',str(path))
    run('adduser','-D','-s','/bin/bash','operator')
    run('passwd','-u','operator')
    identity=pwd.getpwnam('operator')
    directory=Path(identity.pw_dir)/'.ssh'; directory.mkdir(mode=0o700)
    authorized=directory/'authorized_keys'
    authorized.write_bytes(client_key.with_suffix('.pub').read_bytes()); authorized.chmod(0o600)
    for path in (directory,authorized): os.chown(path,identity.pw_uid,identity.pw_gid)
    (client/'.ssh/known_hosts').write_text('127.0.0.1 '+host_key.with_suffix('.pub').read_text())
    (client/'.ssh/known_hosts').chmod(0o600)
    sudo=Path('/etc/sudoers.d/qa395'); sudo.write_text('operator ALL=(root) NOPASSWD: ALL\n'); sudo.chmod(0o440)
    config=private/'sshd_config'; config.write_text(configuration()); config.chmod(0o600)
    Path('/run/sshd').mkdir(mode=0o755,exist_ok=True)
    run('/usr/sbin/sshd','-t','-f',str(config))
    run('/usr/sbin/sshd','-f',str(config),'-E',str(private/'sshd.log'))
    deployment=Path('/opt/voice-platform'); deployment.mkdir(mode=0o700,exist_ok=False)
    shutil.copyfile(private/'deployment.env',deployment/'.env'); (deployment/'.env').chmod(0o600)
    Path('/opt/voice-platform-releases').symlink_to(work/'releases',target_is_directory=True)
    trust=Path('/etc/voice-platform'); trust.mkdir(mode=0o755,exist_ok=False)
    shutil.copyfile(work/'trusted-signing.pub.pem',trust/'release-signing.pub.pem')
    shutil.copyfile(work/'ca.crt','/usr/local/share/ca-certificates/qa395.crt')
    run('update-ca-certificates')
    for _ in range(20):
        try:
            with socket.create_connection(('127.0.0.1',22),timeout=1): break
        except OSError: time.sleep(.1)
    else: raise RuntimeError('Owned loopback SSH did not start')
    return {'scope':'owned-loopback-only','qa_signing_public_sha256':hashlib.sha256((work/'trusted-signing.pub.pem').read_bytes()).hexdigest(),
            'qa_ssh_public_sha256':hashlib.sha256(host_key.with_suffix('.pub').read_bytes()).hexdigest()}
