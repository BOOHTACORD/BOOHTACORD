"""Exact-source, full-payload checks at the native CI artifact boundary."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from tools.ci.native.process import ROOT, VERSIONS, output
from tools.build.client_identity import load
from tools.ci.backend_gates.results import execution, require

PURPOSE={'schema_version':1,'purpose':'windows-ci-acceptance',
         'entrypoint':'integration_test/screen_setup_windows_app.dart','stable_release':False}
RELEASE='clients/flutter/build/windows/x64/runner/Release'
INSTALLER='.out/releases/windows'
BINDING='.out/ci/windows-transfer.json'


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()


def read(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 4_000_000)
    return json.loads(path.read_text(encoding='utf-8'))


def inventory(directory):
    directory=Path(directory)
    require(directory.is_dir() and not directory.is_symlink())
    files={};seen=set();total=0
    for path in sorted(directory.rglob('*')):
        require(not path.is_symlink())
        relative=path.relative_to(directory).as_posix()
        require(all(p and p.rstrip(' .')==p and ':' not in p and '\\' not in p for p in path.relative_to(directory).parts))
        if path.is_dir(): continue
        require(path.is_file() and relative.lower() not in seen)
        seen.add(relative.lower())
        size=path.stat().st_size;total+=size
        require(len(files)<10000 and total <= 2_000_000_000)
        files[relative]={'bytes':size,'sha256':digest(path)}
    require(files)
    return files


def seal(release,installer,source):
    require(isinstance(source,str) and re.fullmatch('[0-9a-f]{40}',source))
    files=inventory(release);packages=inventory(installer)
    manifest=read(release/'artifact-manifest.json')
    require(manifest.get('source_revision') == source and manifest.get('source_dirty') is False
            and manifest.get('platform') == 'windows' and manifest.get('architectures') == ['x64'])
    identity=load('windows')
    require(manifest.get('version') == identity['version']+'+'+identity['native_build']
            and manifest.get('release_id') == identity['release_id']
            and manifest.get('release_order') == identity['release_order']
            and manifest.get('toolchains') == VERSIONS
            and read(installer/'build-identity.json') == identity)
    require(manifest.get('contracts') == {p.name:digest(p) for p in (ROOT/'contracts').glob('*') if p.is_file()})
    expected={k:v for k,v in files.items() if k not in ('artifact-manifest.json','SHA256SUMS')}
    require(manifest.get('files') == expected and read(release/'ci-purpose.json') == PURPOSE)
    require({'boohtacord_desktop.exe','BOOHTACORDRecovery.exe','flutter_windows.dll','libwebrtc.dll'} <= expected.keys()
            and any(k.startswith('data/flutter_assets/') for k in expected))
    lines=[v['sha256']+'  '+k for k,v in expected.items()]
    lines.append(digest(release/'artifact-manifest.json')+'  artifact-manifest.json')
    actual=(release/'SHA256SUMS').read_text(encoding='utf-8').splitlines()
    require(len(actual)==len(lines) and set(actual)==set(lines))
    require(sum(k.endswith('Setup.exe') for k in packages)==1
            and sum(k.endswith('-full.nupkg') for k in packages)==1 and 'build-identity.json' in packages)
    return {'schema_version':1,'source_revision':source,'execution':execution(),
            'purpose':PURPOSE,'release':files,'installer':packages}


def verify(release,installer,binding,source):
    require(binding == seal(release,installer,source))
    return binding


def verify_workspace():
    source=output('git','rev-parse','HEAD')
    import os
    require(os.environ.get('GITHUB_SHA',source)==source)
    return verify(ROOT/RELEASE,ROOT/INSTALLER,read(ROOT/BINDING),source)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('operation',choices=('seal','verify'))
    if parser.parse_args().operation == 'verify': verify_workspace()
    else:
        source=output('git','rev-parse','HEAD')
        import os
        require(os.environ.get('GITHUB_SHA',source)==source)
        value=seal(ROOT/RELEASE,ROOT/INSTALLER,source)
        path=ROOT/BINDING;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(value,sort_keys=True)+'\n',encoding='utf-8')


if __name__ == '__main__': main()
