"""Public native asset contracts reject foreign identity, bytes and QA packages."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from tools.build.client_identity import load
from tools.release.native_artifact.manifest import write
from tools.ci.native.process import output
from . import assets


def rewrite_sums(directory):
    files={p.name:{'sha256':assets.digest(p)} for p in directory.iterdir() if p.name!='SHA256SUMS'}
    (directory/'SHA256SUMS').write_text(''.join(v['sha256']+'  '+k+'\n' for k,v in files.items()))


def fixture(root,platform):
    directory=root/'assets';directory.mkdir();identity=load(platform)
    context={'repository':'Egkurilov/BOOHTACORD','platform':platform,'tag':platform+'-v'+identity['version'],
             'source_revision':output('git','rev-parse','HEAD'),'identity':identity,'execution':{'run_id':'local','run_attempt':'1'}}
    arches={'android':['arm64-v8a','armeabi-v7a','x86_64'],'windows':['x64'],'macos':['arm64','x86_64']}[platform]
    tag=context['tag']
    if platform=='windows':
        native=root/'native';native.mkdir()
        for name in ('boohtacord_desktop.exe','BOOHTACORDRecovery.exe','flutter_windows.dll','libwebrtc.dll'):
            (native/name).write_bytes(b'synthetic native fixture; never executed')
        appid='boohtacord_desktop';signing={'status':'unsigned'}
    else:
        native=directory
        if platform=='android':
            apks={f'BOOHTACORD-{tag}-{abi}.apk':{'certificate_sha256':assets.CERTIFICATE} for abi in arches}
            for name in apks:(directory/name).write_bytes(b'synthetic APK; not signed or executed')
            appid=assets.APPLICATION;signing={'status':'signed','certificate_sha256':assets.CERTIFICATE,'apks':apks}
        else:
            name=f'BOOHTACORD-{tag}.zip';(directory/name).write_bytes(b'synthetic macOS archive; never executed')
            (directory/(name+'.sha256')).write_text(assets.digest(directory/name)+'  '+name+'\n')
            appid='ru.boohtacord.boohtacordDesktop';signing={'status':'adhoc'}
    write(native,platform,arches,appid,signing)
    p=native/'artifact-manifest.json';m=json.loads(p.read_text());m['source_dirty']=False;p.write_text(json.dumps(m))
    rewrite_sums(native)
    if platform=='windows':
        with zipfile.ZipFile(directory/f'BOOHTACORD-{tag}-x64.zip','w') as archive:
            for p in native.iterdir():archive.write(p,p.name)
        (directory/'artifact-manifest.json').write_bytes((native/'artifact-manifest.json').read_bytes())
        (directory/'fixtureSetup.exe').write_bytes(b'synthetic Setup; never executed')
        (directory/('fixture-'+identity['version']+'-full.nupkg')).write_bytes(b'synthetic package')
        (directory/'releases.stable.json').write_text('{}')
        rewrite_sums(directory)
    return directory,context


class AssetTests(unittest.TestCase):
    def test_all_platform_asset_sets_and_signing_contracts(self):
        for platform in ('android','windows','macos'):
            with self.subTest(platform=platform),tempfile.TemporaryDirectory() as name:
                directory,context=fixture(Path(name),platform)
                self.assertEqual(assets.validate(directory,context)['status'],'PASS')

    def test_missing_manifest_foreign_file_checksum_dirty_source_version_and_signature_fail(self):
        for change in ('manifest','extra','checksum','dirty','source','version','signature','tamper'):
            with tempfile.TemporaryDirectory() as name:
                directory,context=fixture(Path(name),'android');p=directory/'artifact-manifest.json';m=json.loads(p.read_text())
                if change=='manifest':p.unlink()
                if change=='extra':(directory/'foreign.apk').write_bytes(b'foreign')
                if change=='checksum':(directory/'SHA256SUMS').write_text('bad')
                if change=='dirty':m['source_dirty']=True
                if change=='source':m['source_revision']='b'*40
                if change=='version':m['version']='9.9.9+9'
                if change=='signature':m['signing']['certificate_sha256']='b'*64
                if change=='tamper':next(directory.glob('*.apk')).write_bytes(b'changed')
                if change in ('dirty','source','version','signature'):p.write_text(json.dumps(m));rewrite_sums(directory)
                with self.subTest(change=change),self.assertRaises(ValueError):assets.validate(directory,context)

    def test_qa_payload_and_zip_traversal_cannot_be_stable_windows_assets(self):
        for change in ('ci-purpose.json','../foreign'):
            with tempfile.TemporaryDirectory() as name:
                directory,context=fixture(Path(name),'windows')
                archive=next(directory.glob('*.zip'))
                with zipfile.ZipFile(archive,'a') as package:package.writestr(change,'fixture')
                rewrite_sums(directory)
                with self.subTest(change=change),self.assertRaises(ValueError):assets.validate(directory,context)
