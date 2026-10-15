"""Pinned official native dependencies for the disposable Windows API/SFU."""
import hashlib
from pathlib import Path, PureWindowsPath
import shutil
import stat
import urllib.request
import zipfile


PACKAGES = {
    'postgres': (
        'https://get.enterprisedb.com/postgresql/postgresql-17.6-1-windows-x64-binaries.zip',
        329891687,
        'd378882abd001a186735acd6f6ba716bca6ccd192e800412d4fd15ed25376b3e'),
    'livekit': (
        'https://github.com/livekit/livekit/releases/download/v1.13.7/livekit_1.13.7_windows_amd64.zip',
        18916724,
        'e539e7d2f75807b9c9202cd2a0bf2cb3d52fc4c52978a6953e0f47bc339fe77f'),
}


def extract_verified(archive, destination, digest):
    with archive.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != digest:
            raise ValueError('Native fixture tool digest mismatch')
    with zipfile.ZipFile(archive) as package:
        total = 0
        seen = set()
        for item in package.infolist():
            name = item.filename
            path = PureWindowsPath(name)
            total += item.file_size
            if (not name or path.root or path.drive or
                    '\\' in name or ':' in name or '..' in path.parts or
                    any(p.rstrip(' .') != p for p in path.parts) or
                    stat.S_ISLNK(item.external_attr >> 16) or
                    name.lower() in seen or total > 2_000_000_000):
                raise ValueError('Unsafe native fixture tool archive')
            seen.add(name.lower())
        destination.mkdir(parents=True, exist_ok=False)
        for item in package.infolist():
            output = destination.joinpath(*item.filename.split('/'))
            if item.is_dir():
                output.mkdir(parents=True, exist_ok=True)
            else:
                output.parent.mkdir(parents=True, exist_ok=True)
                with package.open(item) as source, output.open('xb') as target:
                    shutil.copyfileobj(source, target, length=1024 * 1024)


def prepare(root: Path):
    root.mkdir(parents=True, exist_ok=False)
    for name, (url, size, digest) in PACKAGES.items():
        archive = root / (name + '.zip')
        with urllib.request.urlopen(url, timeout=120) as response, archive.open('xb') as output:
            count = 0
            while chunk := response.read(1024 * 1024):
                count += len(chunk)
                if count > size:
                    raise ValueError('Native fixture tool exceeds pinned size')
                output.write(chunk)
        if count != size:
            raise ValueError('Incomplete native fixture tool')
        extract_verified(archive, root / name, digest)
    return root / 'postgres/pgsql/bin', root / 'livekit/livekit-server.exe'
