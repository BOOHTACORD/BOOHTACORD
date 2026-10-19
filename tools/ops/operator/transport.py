"""Ephemeral pinned SSH identity and finite commands; no private stdout/stderr in logs."""
import ipaddress
import os
from pathlib import Path
import re
import tempfile
from tools.release.delivery.commands import execute
from .policy import require

PIN='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTOd1clMcOJN4YNCn+EDZ6IAM7x99fHD8O8Zk3umZtr'


class SSH:
    def __init__(self,private,env):
        self.root=Path(private);key=env.get('OPERATOR_SSH_PRIVATE_KEY','');require(key and len(key)<=32768)
        host=env.get('DEPLOY_SERVER_IP','');ipaddress.ip_address(host)
        user=env.get('SSH_USER','');require(re.fullmatch('[a-z_][a-z0-9_-]{0,31}',user))
        identity=self.root/'identity';identity.write_text(key+'\n');identity.chmod(0o600)
        known=self.root/'known_hosts';known.write_text(host+' '+PIN+'\n');known.chmod(0o600)
        execute(['ssh-keygen','-y','-f',str(identity)],10)
        self.target=user+'@'+host
        self.options=['-F','/dev/null','-i',str(identity),'-o','IdentitiesOnly=yes','-o','BatchMode=yes',
                      '-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(known),
                      '-o','GlobalKnownHostsFile=/dev/null','-o','ConnectTimeout=10','-o','ConnectionAttempts=1',
                      '-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3','-o','ForwardAgent=no',
                      '-o','ClearAllForwardings=yes','-o','RequestTTY=no','-o','LogLevel=ERROR']

    def command(self,command,timeout,stdin=None):
        return execute(['ssh',*self.options,self.target,command],timeout,stdin=stdin,capture_limit=65536)

    def script(self,path,args,timeout,*,root=False):
        require(all(re.fullmatch(r'[a-zA-Z0-9_./:=+-]+',a) for a in args))
        with path.open('rb') as stream:return self.command(('sudo -n ' if root else '')+'bash -s -- '+' '.join(args),timeout,stream)

    def copy(self,path,remote):
        require(re.fullmatch('/tmp/voice-platform-qa11-buildx-[0-9a-f]{40}-[0-9a-f]{16}',remote))
        execute(['scp',*self.options,str(path),self.target+':'+remote],120)
