"""Authenticate metadata against the committed root; server keys are never roots."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from datetime import datetime, timezone
from urllib.parse import urlsplit
import re
from .sign import DOMAIN

ROOT = Path(__file__).resolve().parents[3]


def verify(envelope, package, public_key, openssl='openssl'):
    if (set(envelope) != {'schema_version','key_id','payload','signature'}
            or envelope['schema_version'] != 1 or len(envelope['payload']) > 16384):
        raise ValueError('Unsupported desktop artifact envelope')
    key_id, encoded = Path(public_key).read_text().strip().splitlines()
    if envelope['key_id'] != key_id: raise ValueError('Unknown publisher')
    raw = base64.b64decode(envelope['payload'], validate=True)
    signature = base64.b64decode(envelope['signature'], validate=True)
    public = base64.b64decode(encoded, validate=True)
    if len(raw)>12288 or len(signature)!=64 or len(public)!=32: raise ValueError('Invalid signature encoding')
    with tempfile.TemporaryDirectory() as temporary:
        folder=Path(temporary)
        (folder/'public.der').write_bytes(bytes.fromhex('302a300506032b6570032100')+public)
        (folder/'signature').write_bytes(signature)
        (folder/'message').write_bytes(DOMAIN+raw)
        result=subprocess.run([openssl,'pkeyutl','-verify','-rawin','-pubin','-keyform','DER','-inkey',str(folder/'public.der'),'-sigfile',str(folder/'signature'),'-in',str(folder/'message')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        if result.returncode: raise ValueError('Publisher signature mismatch')
    value=json.loads(raw)
    from jsonschema import Draft202012Validator, FormatChecker
    Draft202012Validator(json.loads((ROOT/'contracts/desktop-update-artifact.schema.json').read_text()),format_checker=FormatChecker()).validate(value)
    if datetime.fromisoformat(value['expires_at'].replace('Z','+00:00'))<=datetime.now(timezone.utc):raise ValueError('Artifact metadata expired')
    if not re.fullmatch(r'https://github\.com/BOOHTACORD/BOOHTACORD/releases/download/[A-Za-z0-9_][A-Za-z0-9._-]{0,190}/[A-Za-z0-9_][A-Za-z0-9._-]{0,190}',value['download_url']):raise ValueError('Unofficial artifact URL')
    package=Path(package)
    if not package.is_file() or package.stat().st_size!=value['size']:raise ValueError('Artifact size mismatch')
    digest=hashlib.sha256()
    with package.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):digest.update(block)
    if digest.hexdigest()!=value['sha256']:raise ValueError('Artifact digest mismatch')
    return value
