"""One full native payload must survive the build -> GUI boundary unchanged."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import transfer

SOURCE='a'*40


def fixture(root):
    release=root/'release'; installer=root/'installer'; release.mkdir(); installer.mkdir()
    for name in ('boohtacord_desktop.exe','BOOHTACORDRecovery.exe','flutter_windows.dll','libwebrtc.dll',
                 'data/flutter_assets/a.bin','ci-purpose.json'):
        p=release/name;p.parent.mkdir(parents=True,exist_ok=True)
        p.write_text(json.dumps(transfer.PURPOSE) if name == 'ci-purpose.json' else 'synthetic fixture')
    files=transfer.inventory(release)
    manifest={'source_revision':SOURCE,'source_dirty':False,'platform':'windows','architectures':['x64'],
              'files':files,'toolchains':transfer.VERSIONS}
    identity=transfer.load('windows')
    manifest.update(version=identity['version']+'+'+identity['native_build'],release_id=identity['release_id'],
        release_order=identity['release_order'],contracts={p.name:transfer.digest(p) for p in (transfer.ROOT/'contracts').glob('*') if p.is_file()})
    (release/'artifact-manifest.json').write_text(json.dumps(manifest))
    (release/'SHA256SUMS').write_text(''.join(v['sha256']+'  '+k+'\n' for k,v in files.items())+
        transfer.digest(release/'artifact-manifest.json')+'  artifact-manifest.json\n')
    for name in ('sampleSetup.exe','sample-full.nupkg','build-identity.json'):(installer/name).write_text('fixture')
    (installer/'build-identity.json').write_text(json.dumps(identity))
    return release,installer


class TransferTests(unittest.TestCase):
    def test_exact_source_full_inventory_and_checksum_roundtrip(self):
        with tempfile.TemporaryDirectory() as name:
            release,installer=fixture(Path(name))
            binding=transfer.seal(release,installer,SOURCE)
            self.assertEqual(transfer.verify(release,installer,binding,SOURCE),binding)
            self.assertIn('data/flutter_assets/a.bin',binding['release'])

    def test_foreign_dirty_tampered_missing_added_or_symlink_payload_fails(self):
        for change in ('source','dirty','tamper','missing','extra','installer','manifest','checksum','purpose','link'):
            with tempfile.TemporaryDirectory() as name:
                release,installer=fixture(Path(name)); binding=transfer.seal(release,installer,SOURCE)
                if change in ('source','dirty'):
                    p=release/'artifact-manifest.json';m=json.loads(p.read_text())
                    m['source_revision' if change=='source' else 'source_dirty']='b'*40 if change=='source' else True
                    p.write_text(json.dumps(m))
                if change=='tamper':(release/'boohtacord_desktop.exe').write_text('modified')
                if change=='missing':(release/'libwebrtc.dll').unlink()
                if change=='extra':(release/'unlisted.dll').write_text('foreign')
                if change=='installer':(installer/'sampleSetup.exe').write_text('foreign')
                if change=='manifest':binding['release']['artifact-manifest.json']['sha256']='b'*64
                if change=='checksum':(release/'SHA256SUMS').write_text('foreign')
                if change=='purpose':(release/'ci-purpose.json').write_text('{}')
                if change=='link':(release/'link').symlink_to(release/'boohtacord_desktop.exe')
                with self.subTest(change=change),self.assertRaises(ValueError):transfer.verify(release,installer,binding,SOURCE)

    def test_foreign_attempt_or_missing_gui_job_cannot_pass_aggregate(self):
        from . import aggregate
        needs={k:{'result':'success'} for k in aggregate.ROLES}
        row={'source_revision':SOURCE,'status':'PASS','execution':transfer.execution(),
             'manifest_sha256':'b'*64,'recovery':True,'gui_sfu':True}
        aggregate.validate(SOURCE,needs,row)
        for change in ('skip','source','manifest','recovery','gui','attempt'):
            n=copy.deepcopy(needs);r=copy.deepcopy(row)
            if change=='skip':n['windows-gui-sfu']['result']='skipped'
            if change=='source':r['source_revision']='c'*40
            if change=='manifest':r['manifest_sha256']='bad'
            if change=='recovery':r['recovery']=False
            if change=='gui':r['gui_sfu']=False
            if change=='attempt':r['execution']['run_attempt']='99'
            with self.subTest(change=change),self.assertRaises(ValueError):aggregate.validate(SOURCE,n,r)
