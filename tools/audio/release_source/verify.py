"""Authenticate a complete upstream source distribution before extraction."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
from urllib.request import Request, urlopen

LOCK = Path(__file__).with_name('lock.json')


def load():
    return json.loads(LOCK.read_text(encoding='utf-8'))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unpack(archive, output, lock):
    if output.exists():
        raise ValueError('source destination already exists')
    if digest(archive.read_bytes()) != lock['archiveSha256']:
        raise ValueError('archive checksum mismatch')
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            name = PurePosixPath(member.name)
            if (name.is_absolute() or '..' in name.parts or '\\' in member.name
                    or not name.parts or name.parts[0] != lock['root']
                    or not (member.isdir() or member.isfile())):
                raise ValueError('unsafe archive member')
        for name, expected in lock['files'].items():
            source = tar.extractfile(lock['root'] + '/' + name)
            if source is None or digest(source.read()) != expected:
                raise ValueError('file checksum mismatch: ' + name)
        output.mkdir(parents=True, exist_ok=False)
        tar.extractall(output, filter='data')
    return output / lock['root']


def prepare(output, *, archive=None):
    lock = load()
    output = Path(output).resolve()
    if archive is None:
        archive = output.parent / ('rnnoise-' + lock['archiveSha256'] + '.tar.gz')
        if not archive.exists():
            output.parent.mkdir(parents=True, exist_ok=True)
            request = Request(lock['url'], headers={'User-Agent': 'BOOHTACORD-build'})
            with urlopen(request, timeout=90) as response:
                data = response.read(8_000_001)
            if len(data) > 8_000_000 or digest(data) != lock['archiveSha256']:
                raise ValueError('downloaded archive checksum or size mismatch')
            archive.write_bytes(data)
    if output.exists():
        root = output / lock['root']
        if digest(Path(archive).read_bytes()) != lock['archiveSha256']:
            raise ValueError('archive checksum mismatch')
        with tarfile.open(archive) as tar:
            expected = {}
            for member in tar.getmembers():
                if member.isfile():
                    name = PurePosixPath(member.name).relative_to(lock['root'])
                    expected[str(name)] = digest(tar.extractfile(member).read())
        actual = {p.relative_to(root).as_posix(): digest(p.read_bytes())
                  for p in root.rglob('*') if p.is_file() and not p.is_symlink()}
        if actual != expected or any(p.is_symlink() for p in root.rglob('*')):
            raise ValueError('cached source checksum mismatch')
        return root
    return unpack(Path(archive), output, lock)
