import struct
import tempfile
import unittest
from pathlib import Path

from .imports import required_dlls, verify_runtime


def image(dlls):
    data = bytearray(2048)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 128)
    data[128:132] = b'PE\0\0'
    struct.pack_into('<H', data, 134, 1)
    struct.pack_into('<H', data, 148, 240)
    struct.pack_into('<H', data, 152, 0x20b)
    struct.pack_into('<II', data, 272, 4096, (len(dlls) + 1) * 20)
    struct.pack_into('<4I', data, 400, 1536, 4096, 1536, 512)
    cursor = 512 + (len(dlls) + 1) * 20
    for i, name in enumerate(dlls):
        encoded = name.encode() + b'\0'
        struct.pack_into('<I', data, 512 + 20 * i + 12, 4096 + cursor - 512)
        data[cursor:cursor + len(encoded)] = encoded
        cursor += len(encoded)
    return data


class ImportsTests(unittest.TestCase):
    def test_loader_name_is_checked_instead_of_sdk_archive_filename(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            system = root / 'System32'; system.mkdir()
            (system / 'kernel32.dll').touch()
            (root / 'boohtacord_desktop.exe').write_bytes(image(['KERNEL32.dll', 'velopack_libc.dll']))
            (root / 'BOOHTACORDRecovery.exe').write_bytes(image(['KERNEL32.dll']))
            sdk = root / 'velopack_libc_win_x64_msvc.dll'
            sdk.write_bytes(image(['KERNEL32.dll']))
            self.assertEqual(required_dlls(root / 'boohtacord_desktop.exe'), ['KERNEL32.dll', 'velopack_libc.dll'])
            with self.assertRaisesRegex(ValueError, 'velopack_libc.dll'):
                verify_runtime(root, system)
            sdk.rename(root / 'velopack_libc.dll')
            verify_runtime(root, system)

    def test_outside_recovery_helper_cannot_depend_on_app_local_crt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); system = root / 'System32'; system.mkdir()
            (root / 'boohtacord_desktop.exe').write_bytes(image([]))
            (root / 'BOOHTACORDRecovery.exe').write_bytes(image(['VCRUNTIME140.dll']))
            (root / 'VCRUNTIME140.dll').write_bytes(image([]))
            with self.assertRaisesRegex(ValueError, 'static CRT'):
                verify_runtime(root, system)

    def test_malformed_pe_is_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as temporary:
            file = Path(temporary) / 'bad.exe'; file.write_bytes(b'MZ')
            with self.assertRaises(ValueError):
                required_dlls(file)
