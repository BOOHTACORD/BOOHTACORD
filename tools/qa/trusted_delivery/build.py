"""Fresh QA-signed source pair; reuse only bounded verified public layer exports."""
import json
import os
from pathlib import Path
import subprocess
from .receipts import write
from .variant import variant


def build(work):
    proof = json.loads((work/'ci-proof.json').read_text())
    private = work/'private'
    private.mkdir(mode=0o700)
    key, public = private/'signing.pem', work/'trusted-signing.pub.pem'
    try:
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048',
                        '-out', str(key)], check=True, capture_output=True)
        key.chmod(0o600)
        subprocess.run(['openssl', 'pkey', '-in', str(key), '-pubout', '-out', str(public)], check=True, capture_output=True)
        for role in ('current', 'previous'):
            source = work/role
            revision = subprocess.check_output(['git','rev-parse','HEAD'], cwd=source, text=True).strip()
            checks = work/('checks-'+role)
            write(checks, revision, proof[role])
            subprocess.run(['python3','-m','tools.build.server.run','--source',str(source),
                '--checks',str(checks),'--signing-key',str(key),'--output',str(work/'releases')],
                cwd='/qa-builder', env=dict(os.environ, VITE_PUBLIC_ORIGIN='https://qa60.localhost:5443',
                    BOOHTACORD_SERVER_CACHE_ROOT=str(private/'layer-cache')), check=True)
        # Make the collision while the QA key exists. The exact same trust
        # anchor verifies it; neither a new key nor a changed runtime/image is used.
        negative = work/'negative'
        negative.mkdir(mode=0o700)
        newer = proof['previous']['head']
        variant(work/'releases'/newer, negative/newer, key, public, newer)
    finally:
        key.unlink(missing_ok=True)
