"""Read bounded declared components; remote signature/OCI checks remain mandatory."""
import json
import tarfile
from tools.release.bundle.manifest import validate

def declared(path, source):
    allowed = {'api.oci.tar','web.oci.tar','join-sound-processor.oci.tar','runtime.tar.gz',
               'checks.json','manifest.json','manifest.json.sig'}
    seen = set(); expanded = 0
    try:
        with tarfile.open(path,'r:gz') as archive:
            for member in archive:
                if (member.name not in allowed or member.name in seen or not member.isfile()
                        or member.size < 1 or member.size > 2_000_000_000): raise ValueError
                seen.add(member.name); expanded += member.size
                if expanded > 8_000_000_000: raise ValueError
                if member.name != 'manifest.json': continue
                if member.size > 131072: raise ValueError
                stream = archive.extractfile(member)
                if stream is None: raise ValueError
                with stream: value = json.loads(stream.read(131073))
                validate(value)
                if value['source_revision'] != source: raise ValueError
                return tuple(sorted(value['components']))
        raise ValueError
    except (OSError,ValueError,tarfile.TarError,KeyError,TypeError):
        raise ValueError('Release component declaration differs') from None
