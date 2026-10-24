"""An exit status alone cannot prove captures or a source-bound Android APK."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from . import artifacts


class ArtifactTests(unittest.TestCase):
    def test_mandatory_visual_inventory_keeps_all_uiux_capture_scenarios(self):
        self.assertEqual(146, len(artifacts.VISUALS))
        self.assertEqual(len(artifacts.VISUALS), len(set(artifacts.VISUALS)))
        self.assertIn('guild-member-voice-channel.png', artifacts.VISUALS)
        self.assertIn('guild-member-screen-sharing.png', artifacts.VISUALS)
        parity = [name for name in artifacts.VISUALS if name.startswith('parity-')]
        self.assertEqual(90, len(parity))
        self.assertIn('parity-pinned-workspace-320x480-ime180-scale2.png', parity)
        self.assertIn('parity-mini-320x240-scale2.png', parity)
        self.assertIn('parity-search-1440x480-scale2.png', parity)
        self.assertIn('password-reset-visibility-mobile.png', artifacts.VISUALS)
        self.assertIn('flutter-screen-audience-viewer-strip-1024x92@2x.png', artifacts.VISUALS)
        self.assertIn('flutter-screen-viewer-transient-controls-1440x900.png', artifacts.VISUALS)
        self.assertNotIn('message-actions-all-open-actual.png', artifacts.VISUALS)
        self.assertNotIn('message-actions-closed-actual.png', artifacts.VISUALS)
        self.assertNotIn('message-actions-open-actual.png', artifacts.VISUALS)
        self.assertNotIn('message-social-touch-targets.png', artifacts.VISUALS)
        self.assertIn('voice-viewer-participants-room.png', artifacts.VISUALS)
        self.assertIn('voice-viewer-participants-room-open.png', artifacts.VISUALS)
        self.assertIn('voice-viewer-participants-fullscreen-open.png', artifacts.VISUALS)
        self.assertIn('flutter-screen-viewer-mini-player-mobile-393x852.png', artifacts.VISUALS)
        self.assertIn('flutter-channel-favorites-1440x900.png', artifacts.VISUALS)
        self.assertIn('flutter-channel-favorites-mobile-393x852.png', artifacts.VISUALS)
        self.assertIn('flutter-connection-status-desktop-320x380.png', artifacts.VISUALS)
        self.assertIn('flutter-connection-status-mobile-320x380.png', artifacts.VISUALS)
        for channel in ('text-channel', 'dm-conversation'):
            for profile, size in (('mobile', '393x852'), ('mobile-large-text', '393x852'), ('desktop', '1440x900')):
                self.assertIn(f'flutter-{channel}-{profile}-{size}.png', artifacts.VISUALS)

    def test_support_capture_names_are_finite_and_unknown_images_remain_rejected(self):
        from tools.ci.artifact_policy.capture_inventory import complete
        support = {f'support-{width}-text{scale}.png'
                   for width in (320, 393, 1440) for scale in (1.0, 2.0)}
        support.add('support-320-text2-ime.png')
        self.assertEqual(support, {name for name in artifacts.VISUALS if name.startswith('support-')})
        complete('flutter', dict.fromkeys(artifacts.VISUALS))
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys((*artifacts.VISUALS, 'support-user-upload.png')))

    def test_auth_capacity_capture_is_required_without_allowing_arbitrary_auth_images(self):
        from tools.ci.artifact_policy.capture_inventory import complete
        self.assertIn('auth-capacity-mobile.png', artifacts.VISUALS)
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys(name for name in artifacts.VISUALS
                                            if name != 'auth-capacity-mobile.png'))
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys((*artifacts.VISUALS, 'auth-private-upload.png')))

    def test_login_admission_capture_is_mandatory(self):
        from tools.ci.artifact_policy.capture_inventory import complete
        self.assertIn('auth-rate-limit-mobile.png', artifacts.VISUALS)
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys(name for name in artifacts.VISUALS
                                            if name != 'auth-rate-limit-mobile.png'))

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
