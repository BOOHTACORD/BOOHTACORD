"""Prepare two genuine attested QA bundles using the unchanged server builder."""
import json
import os
from pathlib import Path
import subprocess
import shutil
from builder_identity import cache_identity


def build(work):
    from tools.release.bundle.verify import verify_bundle
    from tools.release.bundle.manifest import FILES
    cache = Path('/qa-cache')
    proof = json.loads((work / 'ci-proof.json').read_text())
    expected = {role: proof[role]['head'] for role in ('current', 'previous')}
    identity = cache_identity(proof, Path('/qa-builder'))
    if (cache / 'complete.json').is_file():
        if json.loads((cache / 'complete.json').read_text()) != identity:
            raise ValueError('Retained QA bundle pair differs; select a new empty cache directory')
        for revision in expected.values():
            verify_bundle(cache / revision, cache / 'trusted-signing.pub.pem', revision)
            shutil.copytree(cache / revision, work / 'releases' / revision)
        shutil.copyfile(cache / 'trusted-signing.pub.pem', work / 'trusted-signing.pub.pem')
        (work / 'private').mkdir(mode=0o700)
        return
    private = work / 'private'
    private.mkdir(mode=0o700)
    key = private / 'signing.pem'
    public = work / 'trusted-signing.pub.pem'
    subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(key)], check=True, capture_output=True)
    key.chmod(0o600)
    subprocess.run(['openssl', 'pkey', '-in', str(key), '-pubout', '-out', str(public)], check=True, capture_output=True)
    # This anchor is provisioned before either bundle exists. It is QA-only and
    # is never accepted by a production installation or added to repository trust.
    try:
        for role in ('current', 'previous'):
            source = work / role
            revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
            observed = proof[role]
            if (observed['head'] != revision or observed['status'] != 'success'
                    or set(observed['checks']) != {'backend', 'web', 'contracts'}
                    or any(row['conclusion'] != 'success' for row in observed['checks'].values())):
                raise ValueError('Actual exact-revision CI proof is required')
            receipts = work / ('checks-' + role)
            receipts.mkdir()
            for gate in ('backend', 'web', 'contracts'):
                (receipts / (gate + '.json')).write_text(json.dumps({
                    'source_revision': revision, 'gate': gate, 'status': 'PASS',
                    'observed_ci_run': observed['run'], 'observed_ci_job': observed['checks'][gate]['id'],
                    'scope': 'Authenticated GitHub CI result for this exact source head; QA bundle only',
                }) + '\n')
            environment = dict(os.environ, VITE_PUBLIC_ORIGIN='https://qa60.localhost:5443')
            subprocess.run(['python3', '-m', 'tools.build.server.run', '--source', str(source), '--checks', str(receipts),
                            '--signing-key', str(key), '--output', str(work / 'releases')],
                           cwd='/qa-builder', env=environment, check=True)
        # Retain only immutable built artifacts and the preprovisioned public QA
        # anchor. No application data, volumes or signing private key are cached.
        for revision in expected.values():
            source, target = work / 'releases' / revision, cache / revision
            verify_bundle(source, public, revision)
            target.mkdir(exist_ok=False)
            for name in FILES | {'manifest.json', 'manifest.json.sig'}:
                shutil.copyfile(source / name, target / name)
        shutil.copyfile(public, cache / 'trusted-signing.pub.pem')
        (cache / 'complete.json').write_text(json.dumps(identity))
    finally:
        key.unlink(missing_ok=True)
