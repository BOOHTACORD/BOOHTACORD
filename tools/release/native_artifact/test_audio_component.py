import json
import tempfile
import unittest
from pathlib import Path
from tools.release.native_artifact.audio_component import write_audio_component
from tools.release.native_artifact.audio_component import ROOT


def release_fixture(directory):
    import shutil
    shutil.copyfile(ROOT / 'tools/audio/release_source/lock.json', directory / 'rnnoise-engine.json')
    shutil.copyfile(ROOT / 'tools/audio/runtime_assets/rnnoise/LICENSE-RNNoise-0.2.txt', directory / 'LICENSE-RNNoise-0.2.txt')


class NativeAudioComponentTests(unittest.TestCase):
    def test_windows_records_the_delivered_official_release_and_keeps_android_unchanged(self):
        with tempfile.TemporaryDirectory() as temporary:
            release_fixture(Path(temporary))
            result = write_audio_component(Path(temporary), platform='windows')
            self.assertEqual(result['model_id'], 'rnnoise-release-v0.2')
            self.assertEqual(result['version'], '0.2')
            self.assertEqual(result['model_sha256'], 'dece58eabca6a722a0bd9dbc8dfadba27abac1271760fad65e1071f54717dc78')
            self.assertNotIn('msvc_overlay_sha256', result)
            other = write_audio_component(Path(temporary), platform='android')
            self.assertNotIn('msvc_overlay_sha256', other)
            self.assertNotEqual(other['model_sha256'], result['model_sha256'])

    def test_windows_refuses_missing_or_modified_release_notice(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            with self.assertRaises(FileNotFoundError):
                write_audio_component(directory, platform='windows')
            release_fixture(directory)
            (directory / 'LICENSE-RNNoise-0.2.txt').write_text('wrong')
            with self.assertRaises(ValueError):
                write_audio_component(directory, platform='windows')

    def test_release_sidecars_bind_exact_pinned_source_and_model(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = write_audio_component(Path(temporary))
            sbom = json.loads((Path(temporary) / 'rnnoise-component.cdx.json').read_text())
            self.assertEqual(sbom['bomFormat'], 'CycloneDX')
            self.assertEqual(result['source_commit'], 'cdf196b1e9de2f8ff1003328ebf9a4316477429d')
            self.assertEqual(result['model_sha256'], 'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95')
            self.assertIn('Redistribution', (Path(temporary) / 'LICENSE-RNNoise.txt').read_text())
