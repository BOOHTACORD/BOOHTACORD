"""Read an untrusted export identity; the full OCI verifier must admit it before import."""
import json
import re
import tarfile
from tools.release.bundle.manifest import require


def oci_root_identity(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_nlink == 1
            and path.stat().st_size <= 8*1024**3, 'Missing or oversized OCI export')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Ambiguous OCI export JSON')
            result[key] = value
        return result
    with tarfile.open(path, 'r:*') as archive:
        members = {}
        for count, member in enumerate(archive, 1):
            name = member.name.rstrip('/')
            require(count <= 20000 and name not in members, 'Ambiguous OCI archive entries')
            if member.isdir():
                require(name in ('blobs','blobs/sha256') and member.size == 0, 'Invalid OCI directory')
            else:
                require(member.isfile() and re.fullmatch(r'index\.json|oci-layout|blobs/sha256/[0-9a-f]{64}', name)
                        and name == member.name, 'Invalid OCI archive entry')
            members[name] = member
        require('index.json' in members and 'oci-layout' in members, 'Incomplete OCI export')
        member = members['index.json']
        require(0 < member.size <= 1_000_000 and 0 < members['oci-layout'].size <= 4096, 'Invalid OCI export metadata')
        layout = json.load(archive.extractfile(members['oci-layout']),object_pairs_hook=unique)
        require(layout == {'imageLayoutVersion':'1.0.0'}, 'Invalid OCI image layout')
        index = json.load(archive.extractfile(member),object_pairs_hook=unique)
    roots = index.get('manifests', [])
    require(index.get('schemaVersion') == 2 and isinstance(roots, list) and len(roots) == 1,
            'Ambiguous OCI export root')
    digest = roots[0].get('digest', '')
    require(isinstance(digest, str) and re.fullmatch('sha256:[0-9a-f]{64}', digest), 'Invalid OCI export identity')
    return digest
