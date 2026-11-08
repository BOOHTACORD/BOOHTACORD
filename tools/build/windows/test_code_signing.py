import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from . import code_signing as signing


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'boohtacord_desktop.exe').write_bytes(b'app')
        (self.root / 'record_windows_plugin.dll').write_bytes(b'dll')
        self.config = signing.configuration({'WINDOWS_SIGN_CERT_SHA1': 'a' * 40,
                                             'WINDOWS_SIGN_TIMESTAMP_URL': 'https://time.example.test'})

    def test_configuration_is_optional_but_partial_or_unsafe_values_fail(self):
        self.assertIsNone(signing.configuration({}))
        for env in ({'WINDOWS_SIGN_CERT_SHA1': 'a' * 40},
                    {'WINDOWS_SIGN_CERT_SHA1': 'x' * 40, 'WINDOWS_SIGN_TIMESTAMP_URL': 'https://a.test'},
                    {'WINDOWS_SIGN_CERT_SHA1': 'a' * 40, 'WINDOWS_SIGN_TIMESTAMP_URL': 'http://a.test'},
                    {'WINDOWS_SIGN_CERT_SHA1': 'a' * 40, 'WINDOWS_SIGN_TIMESTAMP_URL': 'https://a.test/" /sha1'}):
            with self.subTest(env=env), self.assertRaises(ValueError):
                signing.configuration(env)

    def test_signs_unsigned_files_preserves_trusted_and_rechecks_all(self):
        exe = self.root / 'boohtacord_desktop.exe'
        dll = self.root / 'record_windows_plugin.dll'
        states = {exe: 'signed', dll: 'unsigned'}
        def sign(path, config): states[path] = 'signed'
        with patch.object(signing, 'owned_signature', return_value=True), \
             patch.object(signing, 'measure', side_effect=lambda p: states[p]), \
             patch.object(signing, 'sign_file', side_effect=sign) as call:
            signing.prepare(self.root, self.config)
        call.assert_called_once_with(dll, self.config)

    def test_invalid_or_still_unsigned_file_stops_packaging(self):
        with patch.object(signing, 'measure', return_value='invalid'), \
             patch.object(signing, 'sign_file') as sign:
            with self.assertRaises(ValueError): signing.prepare(self.root, self.config)
            sign.assert_not_called()
        with patch.object(signing, 'owned_signature', return_value=True), \
             patch.object(signing, 'measure', return_value='unsigned'), \
             patch.object(signing, 'sign_file'):
            with self.assertRaises(ValueError): signing.prepare(self.root, self.config)

    def test_packaged_binaries_must_match_signed_release_and_installer(self):
        package = self.root / 'client.nupkg'
        setup = self.root / 'clientSetup.bin'
        setup.write_bytes(b'setup')
        with zipfile.ZipFile(package, 'w') as archive:
            archive.writestr('lib/app/boohtacord_desktop.exe', b'app')
            archive.writestr('lib/app/record_windows_plugin.dll', b'dll')
        with patch.object(signing, 'owned_signature', return_value=True), \
             patch.object(signing, 'measure', return_value='signed'):
            signing.verify_package(self.root, package, setup, self.config)
        with zipfile.ZipFile(package, 'w') as archive:
            archive.writestr('lib/app/boohtacord_desktop.exe', b'app')
            archive.writestr('lib/app/record_windows_plugin.dll', b'tampered')
        with patch.object(signing, 'owned_signature', return_value=True), \
             patch.object(signing, 'measure', return_value='signed'), self.assertRaises(ValueError):
            signing.verify_package(self.root, package, setup, self.config)

    def test_installer_must_use_requested_certificate_and_timestamp(self):
        with patch.object(signing, 'owned_signature', return_value=False), self.assertRaises(ValueError):
            signing.verify_package(self.root, self.root / 'unused', self.root / 'setup', self.config)

    def test_unexpected_package_binary_is_rejected(self):
        package = self.root / 'client.nupkg'
        with zipfile.ZipFile(package, 'w') as archive:
            archive.writestr('lib/app/boohtacord_desktop.exe', b'app')
            archive.writestr('lib/app/record_windows_plugin.dll', b'dll')
            archive.writestr('lib/app/extra.dll', b'extra')
        with patch.object(signing, 'owned_signature', return_value=True), self.assertRaises(ValueError):
            signing.verify_package(self.root, package, self.root / 'setup', self.config)

    def test_velopack_bootstrap_must_have_trusted_signature(self):
        package = self.root / 'client.nupkg'
        with zipfile.ZipFile(package, 'w') as archive:
            archive.writestr('lib/app/boohtacord_desktop.exe', b'app')
            archive.writestr('lib/app/record_windows_plugin.dll', b'dll')
            archive.writestr('lib/app/Squirrel.exe', b'bootstrap')
        with patch.object(signing, 'owned_signature', return_value=True), \
             patch.object(signing, 'measure', return_value='unsigned'), self.assertRaises(ValueError):
            signing.verify_package(self.root, package, self.root / 'setup', self.config)


if __name__ == '__main__': unittest.main()
