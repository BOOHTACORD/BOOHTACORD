"""Verify exact public native assets and the complete manifest before publication."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile
from tools.ci.native.process import ROOT, VERSIONS
from tools.build.android.signature import CERTIFICATE, APPLICATION
from tools.build.windows.installer import full_package_name
from .source import require

COMMON={'artifact-manifest.json','SHA256SUMS'}
AUDIO={'LICENSE-RNNoise.txt','rnnoise-component.cdx.json'}


def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def checksums(text,files):
    expected={v['sha256']+'  '+name for name,v in files.items()}
    rows=text.splitlines()
    require(len(rows)==len(expected) and set(rows)==expected)


def inventory(directory):
    require(directory.is_dir() and not directory.is_symlink())
    rows={}
    for path in directory.iterdir():
        require(path.is_file() and not path.is_symlink() and re.fullmatch('[A-Za-z0-9_.-]{1,255}',path.name))
        require(0 < path.stat().st_size <= 95_000_000 and path.name.lower() not in {k.lower() for k in rows})
        rows[path.name]={'bytes':path.stat().st_size,'sha256':digest(path)}
    require(0 < len(rows) <= 12)
    return rows


def manifest_identity(manifest,context):
    identity=context['identity'];platform=context['platform']
    require(manifest['schema_version']==1 and manifest['source_revision']==context['source_revision']
            and manifest['source_dirty'] is False and manifest['platform']==platform
            and manifest['version']==identity['version']+'+'+identity['native_build']
            and manifest['release_id']==identity['release_id'] and manifest['release_order']==identity['release_order']
            and manifest['toolchains']==VERSIONS)
    require(manifest['contracts']=={p.name:digest(p) for p in (ROOT/'contracts').glob('*') if p.is_file()})
    expected_arches={'android':['arm64-v8a','armeabi-v7a','x86_64'],'windows':['x64'],'macos':['arm64','x86_64']}
    require(manifest['architectures']==expected_arches[platform])
    require(manifest['application_id']=={'android':APPLICATION,'windows':'boohtacord_desktop',
            'macos':'ru.boohtacord.boohtacordDesktop'}[platform])
    signing=manifest['signing'];status=signing['status']
    if platform=='android':require(status=='signed' and signing.get('certificate_sha256')==CERTIFICATE)
    elif platform=='macos':require(status=='adhoc')
    else:
        require(status in ('signed','unsigned'))
        if status=='signed':require(re.fullmatch('[0-9a-f]{64}',signing.get('certificate_sha256','')))
    return signing


def windows_archive(path,manifest,raw_manifest):
    files={};seen=set();size=0
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            name=item.filename;parts=PurePosixPath(name).parts
            require(parts and PurePosixPath(name).as_posix()==name.rstrip('/') and not name.startswith('/') and '\\' not in name and ':' not in name
                    and all(p not in ('.','..') and p.rstrip(' .')==p for p in parts)
                    and name.lower() not in seen and not stat.S_ISLNK(item.external_attr>>16))
            seen.add(name.lower());size+=item.file_size
            require(len(seen)<=10000 and size<=2_000_000_000)
            if item.is_dir():continue
            require(PurePosixPath(name).name.lower()!='ci-purpose.json')
            with archive.open(item) as stream:hashed=hashlib.file_digest(stream,'sha256').hexdigest()
            files[name]={'bytes':item.file_size,'sha256':hashed}
        require({'artifact-manifest.json','SHA256SUMS','boohtacord_desktop.exe','BOOHTACORDRecovery.exe',
                 'flutter_windows.dll','libwebrtc.dll'} <= files.keys())
        require(files['artifact-manifest.json']['bytes']==len(raw_manifest)
                and files['SHA256SUMS']['bytes']<=4_000_000)
        require(archive.read('artifact-manifest.json')==raw_manifest)
        checksums(archive.read('SHA256SUMS').decode('utf-8'),{k:v for k,v in files.items() if k!='SHA256SUMS'})
    require(manifest['files']=={k:v for k,v in files.items() if k not in COMMON})


def validate(directory,context):
    directory=Path(directory);files=inventory(directory);platform=context['platform'];tag=context['tag']
    require(COMMON <= files.keys())
    path=directory/'artifact-manifest.json';require(path.stat().st_size<=4_000_000)
    raw=path.read_bytes();manifest=json.loads(raw);signing=manifest_identity(manifest,context)
    checksums((directory/'SHA256SUMS').read_text(encoding='utf-8'),{k:v for k,v in files.items() if k!='SHA256SUMS'})
    if platform=='android':
        expected=COMMON|AUDIO|{f'BOOHTACORD-{tag}-{abi}.apk' for abi in manifest['architectures']}
        require(set(files)==expected and set(signing['apks'])==expected-COMMON-AUDIO)
        require(all(info['certificate_sha256']==CERTIFICATE for info in signing['apks'].values()))
    elif platform=='macos':
        name=f'BOOHTACORD-{tag}.zip';expected=COMMON|AUDIO|{name,name+'.sha256'}
        require(set(files)==expected)
        checksums((directory/(name+'.sha256')).read_text(),{name:files[name]})
    else:
        name=f'BOOHTACORD-{tag}-x64.zip'
        setups={k for k in files if k.endswith('Setup.exe')}
        packages={k for k in files if k.endswith('-full.nupkg')}
        require(len(setups)==len(packages)==1 and set(files)==COMMON|{name,'releases.stable.json'}|setups|packages)
        require(next(iter(packages))==full_package_name(context['identity']['version']))
        windows_archive(directory/name,manifest,raw)
    if platform!='windows':require(manifest['files']=={k:v for k,v in files.items() if k not in COMMON})
    return {'schema_version':1,**context,'status':'PASS','signing':signing,'assets':files,
            'manifest_sha256':files['artifact-manifest.json']['sha256'],'notarization':'NOT_RUN'}
