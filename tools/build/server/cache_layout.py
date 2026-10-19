"""Validate local OCI cache bytes before importing them on the trusted builder."""
import hashlib
import json
from pathlib import Path
import re


def inspect(directory, max_bytes):
    directory=Path(directory)
    if directory.is_symlink() or not directory.is_dir(): raise ValueError('Unsafe cache directory')
    if not {'blobs','index.json','oci-layout'}<=set(p.name for p in directory.iterdir()):
        raise ValueError('Incomplete OCI cache')
    size=0; count=0
    for path in directory.rglob('*'):
        if path.is_symlink(): raise ValueError('Linked cache entry')
        if not path.is_dir() and not path.is_file(): raise ValueError('Non-regular cache entry')
        if path.is_file():
            count+=1; size+=path.stat().st_size
            if path.stat().st_nlink!=1 or count>20000 or size>max_bytes: raise ValueError('Cache budget exceeded')
            if path.parent==directory/'blobs/sha256':
                if not re.fullmatch('[a-f0-9]{64}',path.name): raise ValueError('Invalid cache blob identity')
                with path.open('rb') as stream:
                    if hashlib.file_digest(stream,'sha256').hexdigest()!=path.name: raise ValueError('Cache blob digest differs')
    index=directory/'index.json'; layout=directory/'oci-layout'
    if index.stat().st_size>1_000_000 or layout.stat().st_size>4096: raise ValueError('Oversized cache index')
    if json.loads(layout.read_bytes())!={'imageLayoutVersion':'1.0.0'}: raise ValueError('Invalid OCI layout')
    document=json.loads(index.read_bytes()); rows=document.get('manifests')
    if document.get('schemaVersion')!=2 or not isinstance(rows,list) or len(rows)!=1: raise ValueError('Ambiguous cache manifest')
    digest=rows[0].get('digest','')
    if not re.fullmatch('sha256:[a-f0-9]{64}',digest) or not (directory/'blobs/sha256'/digest[7:]).is_file():
        raise ValueError('Missing cache manifest blob')
    return {'digest':digest,'index_sha256':hashlib.sha256(index.read_bytes()).hexdigest(),'bytes':size}
