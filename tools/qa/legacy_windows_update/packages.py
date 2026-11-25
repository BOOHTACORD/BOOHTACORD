"""Official release bytes only; original baseline is pinned independently."""
import hashlib
import json
import re
import urllib.request
from .policy import ORIGIN, SELECTOR, RELEASES, target
from urllib.parse import urlencode
from tools.qa.desktop_updates.windows_tools import download_verified, extract_verified

BASELINE = '1.0.32'
OLD_SOURCE = 'e2b19dfef3568eb00187c5dd35e244aa58ae2942'
OLD_MANIFEST = '6d57223c69e953f13d8a9fea39d3bd042db13fef866584531916dce3f9635599'
OLD_ZIP = 'efcb003c45f1a37732990dd8ff05cff4b601f6697ecb97a3f405c9512c030202'


def read_public(url, limit):
    with urllib.request.urlopen(url,timeout=30) as response:
        if response.status != 200: raise ValueError('Public fixture did not return HTTP200')
        raw = response.read(limit+1)
        headers = {k.lower():v for k,v in response.headers.items()}
    if len(raw) > limit:
        raise ValueError('Public fixture exceeds bound')
    return raw, headers


def read_policy():
    raw, headers = read_public(ORIGIN+'/client-updates?'+urlencode(SELECTOR),16384)
    if (headers.get('cache-control') != 'no-store' or
            headers.get('x-content-type-options') != 'nosniff' or
            'application/json' not in headers.get('content-type','')):
        raise ValueError('Public catalog cache/content policy mismatch')
    document = json.loads(raw)
    target(document)
    return document


def checksums(raw):
    rows = {}
    for line in raw.decode('ascii').splitlines():
        if not line.strip(): continue
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9._-]+)',line.strip())
        if not match or match[2] in rows: raise ValueError('Invalid release checksums')
        rows[match[2]] = match[1]
    if not rows: raise ValueError('Missing release checksums')
    return rows


def release_files(root, version, baseline=False):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',version): raise ValueError('Invalid release version')
    base = RELEASES+'download/windows-v'+version+'/'
    hashes = checksums(read_public(base+'SHA256SUMS',32768)[0])
    raw = read_public(base+'artifact-manifest.json',262144)[0]
    manifest_hash = hashlib.sha256(raw).hexdigest()
    manifest = json.loads(raw)
    if (manifest_hash != hashes.get('artifact-manifest.json') or manifest.get('source_dirty') is not False or
            manifest.get('version') != version+'+'+str(manifest.get('version','').split('+')[-1]) or
            manifest.get('platform') != 'windows' or manifest.get('architectures') != ['x64'] or
            manifest.get('application_id') != 'boohtacord_desktop' or
            not re.fullmatch(r'[0-9a-f]{40}',manifest.get('source_revision',''))):
        raise ValueError('Release manifest identity mismatch')
    if baseline and (manifest_hash != OLD_MANIFEST or manifest.get('source_revision') != OLD_SOURCE):
        raise ValueError('Original baseline identity mismatch')
    name = 'BOOHTACORD-windows-v'+version+'-x64.zip' if baseline else 'boohtacord_desktop-stable-Setup.exe'
    expected = OLD_ZIP if baseline else hashes.get(name)
    if not expected or hashes.get(name) != expected: raise ValueError('Release asset checksum missing')
    with urllib.request.urlopen(urllib.request.Request(base+name,method='HEAD'),timeout=30) as response:
        size = int(response.headers['Content-Length'])
    if not 1 <= size <= 300_000_000 or baseline and size != 26178291:
        raise ValueError('Release asset exceeds approved bounds')
    file = root/name
    download_verified(base+name,file,size,expected)
    if baseline: extract_verified(file,root/'baseline',expected)
    return file, manifest, manifest_hash


def verify_files(directory, manifest):
    for name,item in manifest['files'].items():
        from pathlib import PurePosixPath
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:
            raise ValueError('Unsafe manifest path')
        file = directory/path
        with file.open('rb') as stream: digest = hashlib.file_digest(stream,'sha256').hexdigest()
        if file.stat().st_size != item['bytes'] or digest != item['sha256']:
            raise ValueError('Actual installed release file mismatch')
