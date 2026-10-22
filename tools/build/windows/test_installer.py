import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from .installer import package


class InstallerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.tools = self.root / '.out/desktop-updater/vpk'
        self.tools.mkdir(parents=True)
        (self.tools / 'vpk.exe').touch()
        self.identity = {'version': '1.0.43', 'native_build': '78'}
        self.root_patch = patch('tools.build.windows.installer.ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def test_pinned_tool_is_measured_through_dotnet_then_packaged(self):
        def measure(command, **options):
            self.assertEqual(command, ['dotnet', 'tool', 'list', '--tool-path', str(self.tools)])
            return 'Package Id  Version  Commands\n-------------------------\nvpk  1.2.161  vpk\n'

        def pack(command, **options):
            self.assertEqual(command[:2], [str(self.tools / 'vpk.exe'), 'pack'])
            destination = self.root / '.out/releases/windows'
            (destination / 'boohtacord_desktop-1.0.43-stable-full.nupkg').touch()
            (destination / 'boohtacord_desktop-stable-Setup.exe').touch()

        with patch('tools.build.windows.installer.load', return_value=self.identity), \
             patch('tools.build.windows.installer.subprocess.check_output', side_effect=measure), \
             patch('tools.build.windows.installer.subprocess.run', side_effect=pack):
            self.assertEqual(package(self.root / 'Release'), self.root / '.out/releases/windows')

    def test_other_installed_tool_version_stops_before_pack(self):
        with patch('tools.build.windows.installer.load', return_value=self.identity), \
             patch('tools.build.windows.installer.subprocess.check_output', return_value='vpk 1.2.162 vpk\n'), \
             patch('tools.build.windows.installer.subprocess.run') as pack:
            with self.assertRaisesRegex(ValueError, 'pinned version'):
                package(self.root / 'Release')
            pack.assert_not_called()

    def test_packager_output_must_have_exact_identity_version_and_channel(self):
        for filename in ('boohtacord_desktop-9.9.9-stable-full.nupkg',
                         'boohtacord_desktop-1.0.43-preview-full.nupkg',
                         'foreign-1.0.43-stable-full.nupkg'):
            with self.subTest(filename=filename),tempfile.TemporaryDirectory() as temp:
                root=Path(temp)
                def pack(command, **options):
                    destination=root/'.out/releases/windows'
                    (destination/filename).touch()
                    (destination/'boohtacord_desktop-stable-Setup.exe').touch()
                with patch('tools.build.windows.installer.ROOT',root), \
                     patch('tools.build.windows.installer.load',return_value=self.identity), \
                     patch('tools.build.windows.installer.prepare_packager',return_value=self.tools/'vpk.exe'), \
                     patch('tools.build.windows.installer.subprocess.run',side_effect=pack):
                    with self.assertRaisesRegex(ValueError,'identity, version or channel'):
                        package(root/'Release')
