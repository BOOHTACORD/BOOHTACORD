"""Download the selected immutable artifact and check the actual ZIP digest."""
import json
import os
from pathlib import Path
import shutil
from .artifact_download import location, receive
from .artifact_zip import unpack, MAX_ARCHIVE
from .authority import load


def main():
    root = Path.cwd()/'.out/delivery'
    value = load(root/'producer.json')
    size = value.get('size_in_bytes')
    if (type(size) is not int or not 0 < size <= MAX_ARCHIVE
            or (value.get('format_version') == 2 and value.get('digest') is None)
            or shutil.disk_usage(root).free < size*3+2_147_483_648):
        raise ValueError('Insufficient download authority or disk reserve')
    archive = root/'artifact.zip'
    receive(location(value['id'], os.environ['GITHUB_TOKEN']), archive, size)
    try:
        result = unpack(archive, Path.cwd()/'.out/incoming', value['source_revision'], value['digest'], size)
        (root/'download.json').write_text(json.dumps(result, sort_keys=True)+'\n')
    finally:
        archive.unlink(missing_ok=True)
    print('Verified exact retained artifact ZIP and transport pair')


if __name__ == '__main__': main()
