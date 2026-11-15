"""Sign before CMake embeds the DLL digest; packaging must preserve these bytes."""
import hashlib
import json
import os
from tools.build.windows.code_signing import configuration, owned_signature, sign_file


def prepare(output):
    config = configuration(os.environ)
    if not config:
        return output
    dll = output / 'boohta_deepfilter.dll'
    if not owned_signature(dll, config):
        sign_file(dll, config)
        if not owned_signature(dll, config):
            raise ValueError('DeepFilter signature verification failed before hash binding')
    marker = output / 'engine.json'
    info = json.loads(marker.read_text(encoding='utf-8'))
    info['dllSha256'] = hashlib.sha256(dll.read_bytes()).hexdigest()
    marker.write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')
    return output
