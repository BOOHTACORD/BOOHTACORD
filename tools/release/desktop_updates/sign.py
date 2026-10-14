"""Sign immutable desktop metadata with an owner-held Ed25519 key."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

DOMAIN = b'BOOHTACORD-DESKTOP-ARTIFACT-v1\n'


def sign(payload, package, private_key, public_key, openssl='openssl'):
    package = Path(package)
    if not package.is_file() or not 0 < package.stat().st_size <= 1024**3:
        raise ValueError('Artifact size is unsupported')
    key_id, public = Path(public_key).read_text().strip().splitlines()
    der = subprocess.check_output([openssl, 'pkey', '-in', str(private_key), '-pubout', '-outform', 'DER'])
    if base64.b64encode(der[-32:]).decode() != public:
        raise ValueError('Publisher key differs from the embedded trust root')
    digest = hashlib.sha256()
    with package.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): digest.update(block)
    payload = dict(payload, size=package.stat().st_size, sha256=digest.hexdigest())
    if payload['platform'] == 'macos':
        signature = subprocess.check_output([openssl, 'pkeyutl', '-sign', '-rawin', '-inkey', str(private_key), '-in', str(package)])
        payload['native_signature'] = base64.b64encode(signature).decode()
    serialized = json.dumps(payload, sort_keys=True, ensure_ascii=True, separators=(',', ':')).encode()
    with tempfile.TemporaryDirectory() as directory:
        message = Path(directory)/'message'
        message.write_bytes(DOMAIN + serialized)
        signature = subprocess.check_output([openssl, 'pkeyutl', '-sign', '-rawin', '-inkey', str(private_key), '-in', str(message)])
    return {'schema_version':1, 'key_id':key_id, 'payload':base64.b64encode(serialized).decode(), 'signature':base64.b64encode(signature).decode()}


def main():
    p = argparse.ArgumentParser()
    for field in ['payload', 'package', 'private-key', 'public-key', 'output']: p.add_argument('--'+field, required=True, type=Path)
    p.add_argument('--openssl', default='openssl'); a = p.parse_args()
    document = sign(json.loads(a.payload.read_text()), a.package, a.private_key, a.public_key, a.openssl)
    a.output.write_text(json.dumps(document, indent=2)+'\n')
    print('Signed desktop artifact metadata; private key remains local')


if __name__ == '__main__': main()
