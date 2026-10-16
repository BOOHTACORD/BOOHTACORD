"""Owner-operated Ed25519 key creation. Never prints private key material."""
import argparse
import base64
import hashlib
import os
from pathlib import Path
import subprocess


def create(private_path, public_path, openssl='openssl'):
    private_path = Path(private_path).expanduser()
    public_path = Path(public_path)
    if private_path.exists() or public_path.exists():
        raise ValueError('Refusing to replace an existing publisher key')
    private_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(private_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        subprocess.run([openssl, 'genpkey', '-algorithm', 'ED25519'], stdout=descriptor, check=True)
    finally:
        os.close(descriptor)
    der = subprocess.check_output([openssl, 'pkey', '-in', str(private_path), '-pubout', '-outform', 'DER'])
    if len(der) != 44 or der[:12].hex() != '302a300506032b6570032100':
        raise ValueError('Unexpected Ed25519 public key encoding')
    raw = der[12:]
    key_id = 'boohtacord-desktop-' + hashlib.sha256(raw).hexdigest()[:16]
    public_path.parent.mkdir(parents=True, exist_ok=True)
    public_path.write_text(f'{key_id}\n{base64.b64encode(raw).decode()}\n', encoding='utf-8')
    return key_id


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--private-key', required=True, type=Path)
    parser.add_argument('--public-key', required=True, type=Path)
    parser.add_argument('--openssl', default='openssl')
    args = parser.parse_args()
    print('Created publisher trust root: ' + create(args.private_key, args.public_key, args.openssl))


if __name__ == '__main__':
    main()
