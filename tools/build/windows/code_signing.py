"""Optional Authenticode preparation and packaged-binary verification."""
import json
import os
import re
import shutil
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import urlsplit
from tools.ci.native.process import ROOT, output, run


def configuration(env):
    thumb = env.get('WINDOWS_SIGN_CERT_SHA1', '')
    timestamp = env.get('WINDOWS_SIGN_TIMESTAMP_URL', '')
    if not thumb and not timestamp: return None
    url = urlsplit(timestamp)
    if (not re.fullmatch(r'[0-9a-fA-F]{40}', thumb)
            or not re.fullmatch(r'https?://[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:/[A-Za-z0-9._~/%-]*)?', timestamp)
            or url.scheme not in ('http', 'https')
            or not url.hostname or url.username or url.password or url.query
            or url.fragment or re.search(r'\s', timestamp)):
        raise ValueError('Windows signing requires a certificate thumbprint and RFC 3161 timestamp URL')
    return {'thumbprint': thumb.upper(), 'timestamp': timestamp}


def binaries(root):
    files = sorted(path for path in root.rglob('*')
                   if path.is_file() and path.suffix.lower() in ('.exe', '.dll'))
    if not files or not (root / 'boohtacord_desktop.exe').is_file():
        raise ValueError('Windows application binaries are missing')
    if any(path.is_symlink() for path in files): raise ValueError('Binary symlinks are not supported')
    return files


def measure(path):
    try:
        result = json.loads(output('pwsh', '-NoProfile', '-File',
                                   str(ROOT / 'tools/build/windows/signature.ps1'), '-Path', str(path)))
        return result['status']
    except Exception:
        return 'invalid'


def parameters(config):
    return ['/sha1', config['thumbprint'], '/s', 'My', '/fd', 'SHA256',
            '/tr', config['timestamp'], '/td', 'SHA256']


def sign_file(path, config):
    executable = shutil.which('signtool.exe')
    if not executable:
        sdk = Path(os.environ.get('ProgramFiles(x86)', '')) / 'Windows Kits/10/bin'
        candidates = sorted(sdk.glob('*/x64/signtool.exe'), reverse=True)
        executable = str(candidates[0]) if candidates else None
    if not executable: raise RuntimeError('Windows SDK signtool is unavailable')
    run(executable, 'sign', *parameters(config), str(path))


def owned_signature(path, config):
    try:
        result = output('pwsh', '-NoProfile', '-File', str(ROOT / 'tools/build/windows/owned-signature.ps1'),
                        '-Path', str(path), '-Thumbprint', config['thumbprint'])
        return json.loads(result).get('valid') is True
    except Exception:
        return False


def prepare(root, config):
    files = binaries(root)
    for path in files:
        status = measure(path)
        if status == 'unsigned':
            sign_file(path, config)
            if not owned_signature(path, config): raise ValueError('New signature or timestamp is invalid')
        elif status != 'signed': raise ValueError('Invalid existing Windows signature')
    if any(measure(path) != 'signed' for path in files):
        raise ValueError('Windows application includes an unsigned or invalid binary')
    if not owned_signature(root / 'boohtacord_desktop.exe', config):
        raise ValueError('Windows executable does not use the requested timestamped certificate')


def verify_package(root, package, installer, config):
    if not owned_signature(installer, config): raise ValueError('Windows installer signature or timestamp is invalid')
    with zipfile.ZipFile(package) as archive:
        files = binaries(root)
        expected = {'lib/app/' + path.relative_to(root).as_posix() for path in files}
        actual = [name for name in archive.namelist() if name.lower().endswith(('.exe', '.dll'))]
        extras = set(actual) - expected
        allowed = {'lib/app/BOOHTACORD_ExecutionStub.exe', 'lib/app/Squirrel.exe'}
        if len(actual) != len(set(actual)) or not expected <= set(actual) or not extras <= allowed:
            raise ValueError('Package contains unexpected Windows binaries')
        with tempfile.TemporaryDirectory() as directory:
            for name in sorted(extras):
                info = archive.getinfo(name)
                if info.file_size > 100_000_000: raise ValueError('Packaged bootstrap is too large')
                binary = Path(directory) / Path(name).name
                binary.write_bytes(archive.read(info))
                if measure(binary) != 'signed': raise ValueError('Packaged bootstrap is not trusted')
        for path in files:
            name = 'lib/app/' + path.relative_to(root).as_posix()
            if archive.namelist().count(name) != 1: raise ValueError('Signed binary missing or duplicated in package')
            try: packaged = archive.read(name)
            except KeyError: raise ValueError('Signed binary missing from package') from None
            if packaged != path.read_bytes(): raise ValueError('Packaged binary differs from signed release')
