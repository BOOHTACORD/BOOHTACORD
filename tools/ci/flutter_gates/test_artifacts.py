"""An exit status alone cannot prove captures or a source-bound Android APK."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from . import artifacts


class ArtifactTests(unittest.TestCase):
    def test_mandatory_visual_inventory_keeps_all_uiux_capture_scenarios(self):
        self.assertEqual(35, len(artifacts.VISUALS))
        self.assertIn('password-reset-visibility-mobile.png', artifacts.VISUALS)
        for channel in ('text-channel', 'dm-conversation'):
            for profile, size in (('mobile', '393x852'), ('mobile-large-text', '393x852'), ('desktop', '1440x900')):
                self.assertIn(f'flutter-{channel}-{profile}-{size}.png', artifacts.VISUALS)

    def test_all_current_visual_captures_are_mandatory_valid_nonempty_pngs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            png = b'\x89PNG\r\n\x1a\n' + b'\0\0\0\rIHDR' + (390).to_bytes(4, 'big') + (800).to_bytes(4, 'big') + b'\x08\x06\0\0\0' + b'\0' * 32
            for name in artifacts.VISUALS:
                (root / name).write_bytes(png)
            result = artifacts.visuals(root)
            self.assertEqual(set(artifacts.VISUALS), set(result))
            victim = root / artifacts.VISUALS[0]
            for mutation in ('missing', 'empty', 'not-png', 'symlink'):
                victim.unlink()
                if mutation == 'empty': victim.write_bytes(b'')
                if mutation == 'not-png': victim.write_bytes(b'not a screenshot')
                if mutation == 'symlink': victim.symlink_to(root / artifacts.VISUALS[1])
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    artifacts.visuals(root)
                victim.unlink(missing_ok=True)
                victim.write_bytes(png)

    def test_apk_requires_matching_source_debug_identity_and_measured_checksums(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            apk = root / 'app-debug.apk'; apk.write_bytes(b'actual fixture bytes')
            sha = 'a' * 40
            document = {'schema_version': 1, 'source_revision': sha, 'source_dirty': False,
                        'platform': 'android', 'application_id': 'ru.boohtacord.app',
                        'architectures': ['universal'], 'signing': {'status': 'debug',
                        'certificate_sha256': 'b' * 64, 'apks': {'app-debug.apk': {
                        'certificate_sha256': 'b' * 64}}},
                        'files': {'app-debug.apk': {'bytes': apk.stat().st_size,
                        'sha256': hashlib.sha256(apk.read_bytes()).hexdigest()}}}
            manifest = root / 'artifact-manifest.json'
            def write():
                manifest.write_text(json.dumps(document))
                (root / 'SHA256SUMS').write_text(
                    document['files']['app-debug.apk']['sha256'] + '  app-debug.apk\n' +
                    hashlib.sha256(manifest.read_bytes()).hexdigest() + '  artifact-manifest.json\n')
            write()
            self.assertEqual({'app-debug.apk', 'artifact-manifest.json', 'SHA256SUMS'},
                             set(artifacts.android(root, sha)))
            for key, bad in [('source_revision', 'c' * 40), ('source_dirty', True),
                             ('platform', 'windows'), ('application_id', 'another.app')]:
                old = document[key]; document[key] = bad; write()
                with self.subTest(key=key), self.assertRaises(ValueError): artifacts.android(root, sha)
                document[key] = old
            write(); apk.write_bytes(b'changed APK')
            with self.assertRaises(ValueError): artifacts.android(root, sha)
