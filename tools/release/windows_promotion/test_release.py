"""Promotion accepts the current full release contract and rejects incomplete remote assets."""
import json
from pathlib import Path
import tempfile
import unittest
from tools.release.native_contract.test_assets import fixture
from tools.release.client_updates.windows_release_verification import verify_release
from .intent import digest


class ReleaseTests(unittest.TestCase):
    def test_current_windows_package_and_embedded_checksums(self):
        with tempfile.TemporaryDirectory() as name:
            directory,context=fixture(Path(name),'windows');tag=context['tag']
            release={'tag_name':tag,'draft':False,'prerelease':False,'published_at':'2026-10-19T00:00:00Z',
              'assets':[{'name':p.name,'state':'uploaded','size':p.stat().st_size,'digest':'sha256:'+digest(p.read_bytes()),
                'browser_download_url':f'https://github.com/Egkurilov/BOOHTACORD/releases/download/{tag}/{p.name}'}
                for p in directory.iterdir()]}
            archive=next(directory.glob('*.zip'));manifest=directory/'artifact-manifest.json';sums=directory/'SHA256SUMS'
            self.assertEqual(verify_release(release,archive,manifest,sums,'Egkurilov/BOOHTACORD')['version'],context['identity']['version'])
            release['assets'].pop()
            with self.assertRaises(ValueError):verify_release(release,archive,manifest,sums,'Egkurilov/BOOHTACORD')

    def test_legacy_zip_aliases_and_qa_markers_are_not_promotion_payloads(self):
        from tools.release.client_updates.test_windows_promotion_security import fixture as legacy
        for member in ('data//alias.exe','C:/foreign.exe','CI-PURPOSE.JSON','nested/trailing .'):
            with tempfile.TemporaryDirectory() as name:
                _,release,archive,manifest,sums=legacy(Path(name),member)
                with self.subTest(member=member),self.assertRaises(ValueError):verify_release(release,archive,manifest,sums,'Egkurilov/BOOHTACORD')

    def test_tag_source_and_whole_asset_inventory_are_rechecked(self):
        from .release_proof import fingerprint,verify
        with tempfile.TemporaryDirectory() as name:
            directory,context=fixture(Path(name),'windows');tag=context['tag']
            rows=[{'id':index+1,'name':p.name,'state':'uploaded','size':p.stat().st_size,'digest':'sha256:'+digest(p.read_bytes()),
                'browser_download_url':f'https://github.com/Egkurilov/BOOHTACORD/releases/download/{tag}/{p.name}'}
                for index,p in enumerate(directory.iterdir())]
            release={'tag_name':tag,'draft':False,'prerelease':False,'assets':rows}
            proof={'tag':tag,'source_revision':context['source_revision'],'asset_inventory_sha256':fingerprint(release),
                'archive_sha256':digest(next(directory.glob('*.zip')).read_bytes()),
                'manifest_sha256':digest((directory/'artifact-manifest.json').read_bytes()),'checksums_sha256':digest((directory/'SHA256SUMS').read_bytes())}
            class API:
                wrong=False
                def read(self,path):
                    if path.startswith('/releases/'):return release
                    return {'object':{'type':'commit','sha':'b'*40 if self.wrong else context['source_revision']}}
            api=API();verify({'release':proof},api)
            api.wrong=True
            with self.assertRaises(ValueError):verify({'release':proof},api)
            api.wrong=False;rows[0]['id']+=100
            with self.assertRaises(ValueError):verify({'release':proof},api)
