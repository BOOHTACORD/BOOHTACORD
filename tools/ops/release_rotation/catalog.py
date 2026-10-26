"""Read signed release metadata and remove only its two obsolete OCI archives."""
import json
import os
import re
import stat
from pathlib import Path
from tools.release.bundle.manifest import require, validate
from tools.release.bundle.signature import verify


def regular(path, maximum=None):
    info=path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_nlink==1 and info.st_uid==os.geteuid(),
            'Release artifact must be an owned regular file with one link')
    require(not info.st_mode & 0o022,'Release artifact is writable by another account')
    require(maximum is None or info.st_size<=maximum,'Release metadata is too large')
    return info


def inventory(root, public_key):
    rows=[]
    for directory in root.iterdir():
        if not re.fullmatch('[a-f0-9]{40}',directory.name):continue
        info=directory.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid==os.geteuid() and not info.st_mode & 0o022,
                'Release directory must be owned and cannot be a symlink or writable by others')
        document=directory/'manifest.json'
        if not document.exists():continue  # Legacy source directories are outside this capability.
        stamp=regular(document,262144)
        regular(directory/'manifest.json.sig',16384)
        verify(document,public_key)
        manifest=json.loads(document.read_bytes());validate(manifest)
        require(manifest['source_revision']==directory.name,'Signed source differs from directory')
        archives=[]
        for service in ('api','web'):
            path=directory/(service+'.oci.tar')
            if not path.exists() and not path.is_symlink():continue  # Previously rotated; retain audit metadata.
            item=regular(path)
            require(item.st_size==manifest['files'][path.name]['bytes'],'OCI archive size differs')
            archives.append((path,item.st_dev,item.st_ino,item.st_size))
        rows.append({'revision':directory.name,'time':stamp.st_mtime_ns,'manifest':manifest,'archives':archives})
    return rows


def remove_archives(row):
    removed=0
    for path,device,inode,size in row['archives']:
        info=regular(path)
        require((info.st_dev,info.st_ino,info.st_size)==(device,inode,size),'Archive changed during retention')
        path.unlink();removed+=info.st_blocks*512
    return removed


def previous(root,current):
    path=root/current/'deployment-readback.json';regular(path,65536)
    receipt=json.loads(path.read_bytes())
    value=receipt.get('previous_source_revision')
    require(receipt.get('status')=='PASS' and receipt.get('source_revision')==current
            and isinstance(value,str) and re.fullmatch('[a-f0-9]{40}',value),
            'Previous successful release cannot be established')
    if value==current:
        # An idempotent reinstall can record itself as previous; preserve the last
        # other successful installation instead. Its manifest is verified in inventory.
        others=[]
        for directory in root.iterdir():
            if directory.name==current or not re.fullmatch('[a-f0-9]{40}',directory.name):continue
            installed=directory/'installed.json'
            if not installed.exists():continue
            info=regular(installed,16384);item=json.loads(installed.read_bytes())
            if item.get('status')=='PASS' and item.get('source_revision')==directory.name:
                others.append((info.st_mtime_ns,directory.name))
        require(bool(others),'Previous successful release cannot be established')
        value=max(others)[1]
    return value
