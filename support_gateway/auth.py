"""Ed25519 authentication independent of telemetry consent and browser sessions."""
import base64
import hashlib
import subprocess
import tempfile
from pathlib import Path
from .policy import hex_value, require

def canonical(method,path,stamp,nonce,body):
    return f'boohtacord-support-v1\n{method}\n{path}\n{stamp}\n{nonce}\n{hashlib.sha256(body).hexdigest()}'.encode()

def authenticate(store,headers,method,path,body,now):
    public=headers.get('X-Support-Key','');nonce=headers.get('X-Support-Nonce','')
    require(hex_value(public,64) and hex_value(nonce,32))
    stamp=int(headers.get('X-Support-Time','0'));require(abs(now-stamp)<=300)
    signature=base64.b64decode(headers.get('X-Support-Signature',''),validate=True);require(len(signature)==64)
    key=bytes.fromhex(public)
    with tempfile.TemporaryDirectory(prefix='support-proof-') as directory:
        root=Path(directory)
        (root/'key').write_bytes(bytes.fromhex('302a300506032b6570032100')+key)
        (root/'body').write_bytes(canonical(method,path,stamp,nonce,body));(root/'sig').write_bytes(signature)
        verified=subprocess.run(['openssl','pkeyutl','-verify','-pubin','-keyform','DER','-inkey',str(root/'key'),'-rawin','-in',str(root/'body'),'-sigfile',str(root/'sig')],capture_output=True,timeout=5)
        require(verified.returncode==0)
    tenant=hashlib.sha256(key).hexdigest();store.nonce(tenant,nonce,now)
    return tenant
