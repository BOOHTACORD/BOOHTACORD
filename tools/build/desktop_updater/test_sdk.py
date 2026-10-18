"""Pinned SDK cache and repair tests without network access."""
import hashlib
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from . import sdk


class MacSDKTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='updater sdk ')
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.destination = root / 'clients/flutter/macos/Updaters'
        package = io.BytesIO()
        with tarfile.open(fileobj=package, mode='w') as archive:
            for name, content in [
                ('Sparkle.framework/Versions/B/Sparkle', b'pinned binary'),
                ('Sparkle.framework/Versions/B/Headers/Sparkle.h', b'// header'),
            ]:
                entry = tarfile.TarInfo(name)
                entry.size = len(content)
                archive.addfile(entry, io.BytesIO(content))
            for name, target in [('Versions/Current', 'B'),
                                 ('Sparkle', 'Versions/Current/Sparkle'),
                                 ('Headers', 'Versions/Current/Headers')]:
                entry = tarfile.TarInfo('Sparkle.framework/' + name)
                entry.type = tarfile.SYMTYPE
                entry.linkname = target
                archive.addfile(entry)
        self.package = package.getvalue()
        self.digest = hashlib.sha256(self.package).hexdigest()
        self.addCleanup(patch.stopall)
        patch.object(sdk, 'ROOT', root).start()
        patch.dict(sdk.SDK, macos=('https://example.invalid/sdk', self.digest)).start()
        self.download = patch.object(sdk.urllib.request, 'urlopen',
                                     side_effect=lambda *a, **kw: io.BytesIO(self.package)).start()

    def test_first_prepare_extracts_framework_symlinks_and_reuses_cache_offline(self):
        self.assertEqual(sdk.prepare('macos'), self.destination)
        self.assertTrue((self.destination / 'Sparkle.framework/Headers/Sparkle.h').is_file())
        self.assertTrue((self.destination / 'Sparkle.framework/Sparkle').is_symlink())
        self.download.side_effect = AssertionError('valid cache must work offline')
        self.assertEqual(sdk.prepare('macos'), self.destination)
        self.assertEqual(self.download.call_count, 1)

    def test_missing_header_repairs_cache_even_with_marker_and_binary(self):
        sdk.prepare('macos')
        header = self.destination / 'Sparkle.framework/Headers/Sparkle.h'
        header.unlink()
        sdk.prepare('macos')
        self.assertTrue(header.is_file())
        self.assertEqual(self.download.call_count, 2)

    def test_digest_mismatch_does_not_extract_or_mark_sdk(self):
        self.download.side_effect = lambda *a, **kw: io.BytesIO(b'wrong package')
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            sdk.prepare('macos')
        self.assertFalse((self.destination / 'sdk.sha256').exists())
        self.assertFalse((self.destination / 'Sparkle.framework').exists())
