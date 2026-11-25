"""Keep resource ownership and the final receipt in the same lifetime boundary."""
from contextlib import contextmanager
import json
from pathlib import Path
import re
import secrets
import shutil
import tempfile
import time


def create_root(parent):
    root=Path(tempfile.mkdtemp(prefix='boohtacord-legacy-',dir=parent)).resolve()
    token=secrets.token_hex(16)
    (root/'.legacy-owner').write_text(token,encoding='ascii')
    return root,token


def remove_root(root,parent,token):
    root,parent=Path(root),Path(parent).resolve()
    if (not re.fullmatch(r'boohtacord-legacy-[a-z0-9_]{8}',root.name) or
            root.is_symlink() or root.is_junction() or root.resolve().parent!=parent or
            not re.fullmatch(r'[a-f0-9]{32}',token) or
            (root/'.legacy-owner').read_text(encoding='ascii')!=token):
        raise ValueError('Refusing an unowned fixture root')
    deadline=time.monotonic()+10
    while True:
        if root.is_symlink() or root.is_junction() or root.resolve().parent!=parent:
            raise ValueError('Owned fixture root changed during cleanup')
        try:
            shutil.rmtree(root)
            return
        except (PermissionError,FileNotFoundError):
            if not root.exists(): return
            if time.monotonic()>=deadline: raise
            time.sleep(.25)


@contextmanager
def scope(parent,report,file):
    root,token=create_root(parent)
    try:
        try: yield root
        except BaseException:
            report['status']='FAIL'
            raise
    finally:
        try:
            remove_root(root,parent,token)
            report['resources_removed']=True
        except BaseException:
            report['status']='FAIL';report['resources_removed']=False
            raise
        finally:
            file.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
