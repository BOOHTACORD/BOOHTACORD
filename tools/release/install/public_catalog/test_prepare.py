import io
import os
from pathlib import Path
import stat
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from tools.release.archive.extract import extract
from tools.release.install.runtime import prepare_environment


class PublicCatalogPermissionsTests(unittest.TestCase):
    def fixture(self, root):
        archive=root/'runtime.tar'; data=b'{"catalog_revision":61,"entries":[]}'
        with tarfile.open(archive,'w') as stream:
            item=tarfile.TarInfo('deploy/client-updates/catalog.json');item.size=len(data)
            stream.addfile(item,io.BytesIO(data))
        old=os.umask(0o077)
        try:extract(archive,root/'release',max_bytes=4096)
        finally:os.umask(old)
        host=root/'host.env';host.write_text('PUBLIC_HOST=localhost\n');host.chmod(0o600)
        return root/'release',host,data

    def assert_modes(self, release):
        if os.name=='posix':
            self.assertEqual(stat.S_IMODE((release/'deploy/client-updates').stat().st_mode),0o755)
            self.assertEqual(stat.S_IMODE((release/'deploy/client-updates/catalog.json').stat().st_mode),0o644)
            self.assertEqual(stat.S_IMODE((release/'.env').stat().st_mode),0o600)

    def test_private_umask_catalog_readability_and_private_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            release,host,data=self.fixture(Path(tmp));parent=(release/'deploy').stat().st_mode
            prepare_environment(release,host);self.assert_modes(release)
            self.assertEqual((release/'deploy').stat().st_mode,parent)
            self.assertEqual((release/'deploy/client-updates/catalog.json').read_bytes(),data)
            self.assertEqual((release/'.env').read_bytes(),host.read_bytes())

    def test_reused_release_repairs_only_catalog_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            release,host,data=self.fixture(Path(tmp));prepare_environment(release,host)
            (release/'deploy/client-updates').chmod(0o700)
            (release/'deploy/client-updates/catalog.json').chmod(0o600)
            prepare_environment(release,host);self.assert_modes(release)
            self.assertEqual((release/'deploy/client-updates/catalog.json').read_bytes(),data)

    def test_legacy_release_without_catalog_keeps_environment_behavior(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);release=root/'release';release.mkdir();host=root/'host';host.write_text('PRIVATE=example\n')
            prepare_environment(release,host)
            self.assertEqual((release/'.env').read_bytes(),host.read_bytes())
            self.assertFalse((release/'deploy').exists())

    def test_missing_catalog_in_present_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            release,host,_=self.fixture(Path(tmp));(release/'deploy/client-updates/catalog.json').unlink()
            with self.assertRaises(ValueError):prepare_environment(release,host)

    def test_irregular_public_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            release,host,_=self.fixture(Path(tmp));public=release/'deploy/client-updates'
            (public/'catalog.json').unlink();public.rmdir();public.write_text('not-directory')
            with self.assertRaises(ValueError):prepare_environment(release,host)

    def test_symlink_components_are_rejected_before_any_chmod(self):
        for name in ['deploy','client-updates','catalog.json']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                release,host,_=self.fixture(Path(tmp));original=Path.is_symlink
                with patch.object(Path,'is_symlink',lambda p: p.name==name or original(p)):
                    with self.assertRaises(ValueError):prepare_environment(release,host)

    def test_hardlinked_catalog_is_rejected_before_chmod(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);release,host,_=self.fixture(root)
            os.link(release/'deploy/client-updates/catalog.json',root/'alias')
            with self.assertRaises(ValueError):prepare_environment(release,host)
