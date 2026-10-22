import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from .verify import verify

class IpaVersionTest(unittest.TestCase):
    def package(self, extension_version='1.0.45', extension_build='80'):
        directory = tempfile.TemporaryDirectory(); self.addCleanup(directory.cleanup)
        path = Path(directory.name)/'app.ipa'
        with zipfile.ZipFile(path,'w') as archive:
            for suffix,bundle,version,build in [('', 'ru.boohtacord.app.test', '1.0.45', '80'),('/PlugIns/ScreenShareExtension.appex', 'ru.boohtacord.app.test.ScreenShareExtension',extension_version,extension_build)]:
                archive.writestr('Payload/BOOHTACORD.app'+suffix+'/Info.plist',plistlib.dumps({'CFBundleIdentifier':bundle,'CFBundleShortVersionString':version,'CFBundleVersion':build}))
        return path

    def test_app_and_extension_must_have_the_same_release_identity(self):
        result=verify(self.package(),'1.0.45','80','ru.boohtacord.app.test')
        self.assertEqual(len(result['bundles']),2)

    def test_archiving_runner_alone_does_not_validate_extension(self):
        with self.assertRaises(ValueError): verify(self.package('1.0.0','1'),'1.0.45','80','ru.boohtacord.app.test')

    def test_extension_bundle_id_must_belong_to_this_distribution(self):
        with self.assertRaises(ValueError): verify(self.package(),'1.0.45','80','ru.boohtacord.app')
