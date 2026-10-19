"""Private bounded local exports; no public/PR cache or global Docker pruning."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
from .cache_layout import inspect

OWNER={'kind':'boohtacord-server-layer-cache','version':1}
SERVICES=('api','web')


def namespace(root,service):
    paths={'api':('backend/Dockerfile','backend/go.mod','backend/go.sum'),
           'web':('clients/web/Dockerfile','clients/web/package.json','clients/web/package-lock.json')}[service]
    values={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ('tools/toolchains.json',*paths)}
    return hashlib.sha256(json.dumps({'version':1,'service':service,'inputs':values},sort_keys=True).encode()).hexdigest()


class LayerCache:
    def __init__(self,root,*,max_bytes=4*1024**3):
        self.root=Path(root);self.max_bytes=max_bytes;self.report={};self.pending={};self.lock=None

    def __enter__(self):
        import fcntl
        root=self.root
        if not root.is_absolute() or root.resolve()!=root or any(c in str(root) for c in ',\r\n'):
            raise ValueError('Cache root must be canonical and private')
        fresh=not root.exists()
        if fresh:root.mkdir(mode=0o700,parents=True)
        if root.stat().st_uid!=os.getuid() or root.stat().st_mode&0o777!=0o700:
            raise ValueError('Foreign cache ownership or permissions')
        owner=root/'.owner.json'
        if fresh:owner.write_text(json.dumps(OWNER))
        if (owner.is_symlink() or not owner.is_file() or owner.stat().st_nlink!=1
                or owner.stat().st_size>1024 or json.loads(owner.read_bytes())!=OWNER):
            raise ValueError('Foreign cache root')
        fd=os.open(root/'.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        try:
            if os.fstat(fd).st_nlink!=1 or os.fstat(fd).st_uid!=os.getuid():raise ValueError('Linked cache lease')
            fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
            allowed={'.owner.json','.lock'}|{s+suffix for s in SERVICES for suffix in ('','-stage','.meta.json','.meta.tmp')}
            if any(p.name not in allowed or p.is_symlink() or
                   (p.is_file() and p.stat().st_nlink!=1) for p in root.iterdir()):
                raise ValueError('Unknown or linked cache root entry')
            for service in SERVICES:self.remove(self.staging(service))
        except (OSError,ValueError):
            os.close(fd);raise ValueError('Cache lease or ownership validation failed') from None
        self.lock=fd
        return self

    def staging(self,service):return self.root/(service+'-stage')

    def remove(self,path):
        if path.is_symlink():raise ValueError('Linked cache generation')
        if path.exists():
            if path.parent!=self.root or not path.is_dir():raise ValueError('Foreign cache generation')
            shutil.rmtree(path)

    def arguments(self,service,key):
        if service not in SERVICES or not re.fullmatch('[a-f0-9]{64}',key):raise ValueError('Invalid cache namespace')
        stage=self.staging(service);self.remove(stage)
        record={'namespace':key,'import':'COLD','export':'PENDING'};self.report[service]=record
        args=[];active=self.root/service;meta=self.root/(service+'.meta.json')
        if active.exists() or active.is_symlink():
            try:
                if meta.is_symlink() or meta.stat().st_size>4096:raise ValueError
                previous=json.loads(meta.read_bytes())
                if previous['namespace']==key:
                    actual=inspect(active,self.max_bytes)
                    if previous!={'namespace':key,**actual}:raise ValueError
                    args=['--cache-from',f'type=local,src={active},digest={actual["digest"]}']
                    record['import']='WARM_VERIFIED'
            except (OSError,ValueError,KeyError,TypeError):record['import']='REJECTED'
        if shutil.disk_usage(self.root).free<self.max_bytes+2*1024**3:
            record['export']='DISABLED_LOW_DISK';self.pending.pop(service,None)
            return args
        stage.mkdir(mode=0o700);self.pending[service]=key
        return [*args,'--cache-to',f'type=local,dest={stage},mode=max,tag=boohtacord-master-v1,reset=true']

    def publish(self,service,key):
        if service not in self.pending:return
        if self.pending[service]!=key:raise ValueError('Cache publication namespace differs')
        stage=self.staging(service);actual=inspect(stage,self.max_bytes)
        self.remove(self.root/service);stage.rename(self.root/service)
        temporary=self.root/(service+'.meta.tmp');temporary.write_text(json.dumps({'namespace':key,**actual}))
        temporary.replace(self.root/(service+'.meta.json'))
        self.report[service].update(export='VERIFIED',retained_bytes=actual['bytes'])
        self.pending.pop(service)

    def __exit__(self,*exc):
        import fcntl
        try:
            for service in SERVICES:self.remove(self.staging(service))
        finally:
            fcntl.flock(self.lock,fcntl.LOCK_UN);os.close(self.lock)
