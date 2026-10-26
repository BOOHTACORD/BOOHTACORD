"""Bind local results to tracked and untracked source, excluding build outputs."""
import hashlib
from pathlib import Path
import subprocess

EXTENSIONS={'.go','.mod','.sum','.py','.json','.yaml','.yml','.ts','.vue','.js','.dart','.lock','.kt','.swift','.xml','.plist','.entitlements','.xcconfig','.pbxproj','.kts','.cmake','.cpp','.h','.cc','.sql','.webmanifest','.html','.css','.png'}

def identity(root):
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode('utf-8').split('\0')
    new=subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=root).decode('utf-8').split('\0')
    digest=hashlib.sha256();count=0
    for name in sorted(set(tracked+new)):
        if not name or name.split('/')[0] not in {'backend','clients','contracts','tools','deploy','docker'}:continue
        path=root/name
        if not path.is_file() or path.is_symlink() or (path.suffix not in EXTENSIONS and not path.name.startswith('Dockerfile')):continue
        digest.update(name.encode('utf-8')+b'\0'+hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix!='.png' else path.read_bytes()).digest());count+=1
    return {'base_revision':revision,'source_snapshot_sha256':digest.hexdigest(),'source_files':count}
