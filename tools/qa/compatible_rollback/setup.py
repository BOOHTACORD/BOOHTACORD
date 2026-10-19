"""Start the exact retained Compose topology in the otherwise empty QA daemon."""
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
import hashlib
import platform
from isolation import LABEL, egress_name


def prepare(work):
    from tools.release.archive.extract import extract
    from tools.release.bundle.verify import verify_bundle
    from tools.release.bundle.compatibility import compatible_rollback
    from tools.release.install.docker import load_images, verify_running
    from tools.release.install.runtime import prepare_environment
    from tools.release.install.paths import compose_arguments
    from tools.release.install.state import write_receipt
    manifests = []
    for role in ('current', 'previous'):
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=work / role, text=True).strip()
        directory = work / 'releases' / revision
        manifest = verify_bundle(directory, work / 'trusted-signing.pub.pem', revision)
        expanded = work / ('runtime-' + role)
        extract(directory / 'runtime.tar.gz', expanded, max_bytes=100_000_000)
        for item in expanded.iterdir():
            item.rename(directory / item.name)
        manifests.append(manifest)
    current, previous = manifests
    compatible_rollback(current, previous)
    directory = work / 'releases' / current['source_revision']
    password = secrets.token_urlsafe(24)
    values = {
        'PUBLIC_HOST': 'qa60.localhost', 'PUBLIC_ORIGIN': 'https://qa60.localhost:5443',
        'POSTGRES_USER': 'voice_platform', 'POSTGRES_DB': 'voice_platform',
        'POSTGRES_PASSWORD': secrets.token_urlsafe(24), 'LIVEKIT_API_KEY': 'qa60-only',
        'LIVEKIT_API_SECRET': secrets.token_urlsafe(32), 'LIVEKIT_NODE_IP': '127.0.0.1',
        'LIVEKIT_PUBLIC_WS_URL': 'wss://qa60.localhost:5443',
        # The first dynamic endpoint in a fresh bridge takes .2. Keep the proxy
        # outside the few dynamically allocated service addresses, using the
        # existing Compose configuration inputs and the exact API trust pin.
        'PRIVATE_PROXY_IP': '172.30.254.250', 'TRUSTED_PROXY_CIDRS': '172.30.254.250/32',
        'API_IMAGE': 'voice-platform-api@' + current['components']['api']['index_digest'],
        'WEB_IMAGE': 'voice-platform-web@' + current['components']['web']['index_digest'],
    }
    environment = work / 'private' / 'deployment.env'
    environment.write_text(''.join(k + '=' + v + '\n' for k, v in values.items()))
    environment.chmod(0o600)
    prepare_environment(directory, environment)
    load_images(directory, current)
    compose = ['docker', 'compose', *compose_arguments(directory)]
    # Retained SFU configuration performs real public STUN discovery. Provide
    # that owned fixture dependency before its process starts; management ports
    # stay unpublished and API/proxy networks are the signed topology's networks.
    owner = (work / 'owner').read_text()
    egress = egress_name(owner)
    subprocess.run(['docker', 'network', 'create', '--label', LABEL + '=' + owner, egress], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([*compose, 'create', 'livekit'], check=True)
    sfu = subprocess.check_output([*compose, 'ps', '--all', '--quiet', 'livekit'], text=True).strip()
    if not sfu or '\n' in sfu:
        raise RuntimeError('Expected one owned created SFU')
    subprocess.run(['docker', 'network', 'connect', egress, sfu], check=True)
    subprocess.run([*compose, 'up', '-d', '--wait', '--no-recreate', 'postgres', 'livekit', 'web'], check=True)
    subprocess.run([*compose, 'run', '--rm', '--no-deps', 'migrate'], check=True)
    subprocess.run([*compose, '--profile', 'operator', 'run', '--rm', '-T', '--no-deps', 'bootstrap-admin',
                    '--login', 'qa_admin', '--password-stdin'], input=password + '\n', text=True, check=True, stdout=subprocess.DEVNULL)
    # New named attachment volumes need the shipping nonroot API's ownership.
    subprocess.run([*compose, 'create', 'api'], check=True)
    mount = subprocess.check_output(['docker', 'volume', 'inspect', '--format', '{{.Mountpoint}}',
                                    'voice-platform_attachments-data'], text=True).strip()
    os.chown(mount, 65532, 65532)
    os.chmod(mount, 0o700)
    subprocess.run([*compose, 'up', '-d', '--no-deps', 'api', 'proxy'], check=True)
    for _ in range(90):
        result = subprocess.run([*compose, 'cp', 'proxy:/data/caddy/pki/authorities/local/root.crt', str(work / 'ca.crt')], capture_output=True)
        if result.returncode == 0:
            break
        time.sleep(1)
    else:
        raise RuntimeError('Owned Caddy CA did not become available')
    os.environ['CURL_CA_BUNDLE'] = str(work / 'ca.crt')
    subprocess.run(['curl', '-fsS', '--retry', '30', '--retry-connrefused', 'https://qa60.localhost/api/v1/health'], check=True)
    verify_running(directory, current)
    write_receipt(directory, current)
    probe = directory / 'tools/release/rollout/livekit_private_path.py'
    from readiness import wait_roomservice
    roomservice_readiness = wait_roomservice(['python3', str(probe), str(directory)])
    from storage import container
    supporting = {}
    for service in ('postgres', 'livekit', 'proxy'):
        observed = json.loads(subprocess.check_output(['docker', 'inspect', container(service)]))[0]
        if service == 'livekit':
            bindings = observed['HostConfig'].get('PortBindings') or {}
            if bindings.get('7880/tcp') or bindings.get('6789/tcp'):
                raise RuntimeError('Owned SFU management interfaces must remain unpublished')
        supporting[service] = {'reference': observed['Config']['Image'], 'image_id': observed['Image']}
    metadata = {
        'fixture_roomservice_readiness': roomservice_readiness,
        'kernel': platform.release(), 'machine': platform.machine(), 'python': platform.python_version(),
        'docker': subprocess.check_output(['docker', 'version', '--format', '{{.Server.Version}}'], text=True).strip(),
        'compose': subprocess.check_output(['docker', 'compose', 'version', '--short'], text=True).strip(),
        'supporting_images': supporting,
        'qa_signing_public_key_sha256': hashlib.sha256((work / 'trusted-signing.pub.pem').read_bytes()).hexdigest(),
        'scope': 'Isolated QA signing and runtime; source bundles independently verified before every transition',
        'private_proxy_ip': values['PRIVATE_PROXY_IP'], 'trusted_proxy_cidrs': values['TRUSTED_PROXY_CIDRS'],
        'fixture_sfu_egress': 'Owned additional bridge for actual retained-config STUN; no management port published',
    }
    (work / 'environment.json').write_text(json.dumps(metadata, indent=2) + '\n')
    private = {'password': password, 'current': current['source_revision'], 'previous': previous['source_revision']}
    (work / 'private' / 'browser.json').write_text(json.dumps(private))
    (work / 'private' / 'browser.json').chmod(0o600)
    return private
