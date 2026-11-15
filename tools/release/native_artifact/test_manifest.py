import tempfile
import unittest
from pathlib import Path
from .manifest import write, digest


class NativeArtifactMetadataTests(unittest.TestCase):
    def test_unsigned_artifact_is_explicit_and_manifest_is_checksummed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            from .test_audio_component import release_fixture
            release_fixture(root)
            artifact = root / 'client.exe'; artifact.write_bytes(b'artifact fixture')
            result = write(root, 'windows', ['x64'], 'boohtacord_desktop', {'status': 'unsigned'})
            self.assertEqual(result['signing'], {'status': 'unsigned'})
            self.assertEqual(result['files']['client.exe']['sha256'], digest(artifact))
            self.assertIn(digest(root / 'artifact-manifest.json'), (root / 'SHA256SUMS').read_text())
            again = write(root, 'windows', ['x64'], 'boohtacord_desktop', {'status': 'unsigned'})
            self.assertEqual(again, result)

    def test_cannot_claim_a_signature_without_the_certificate(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError): write(Path(temporary), 'android', ['arm64'], 'ru.boohtacord.app', {'status': 'signed'})
