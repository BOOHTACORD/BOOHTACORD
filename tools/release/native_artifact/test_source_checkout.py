"""Pinned native component provenance must survive Windows Git checkout."""
import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from .audio_component import ROOT, write_audio_component


class NativeSourceCheckoutTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name) / 'source'
        self.checkout = Path(self.temporary.name) / 'checkout'
        self.source.mkdir()
        native = Path('clients/flutter/packages/flutter_webrtc/common/rnnoise')
        paths = [p.relative_to(ROOT) for p in (ROOT / native / 'upstream').rglob('*') if p.is_file()]
        paths += [native / 'msvc_stack_array_compat.cmake', Path('tools/audio/rnnoise_build_lock.json')]
        paths += [Path('tools/audio/release_source/lock.json'),
                  Path('tools/audio/runtime_assets/rnnoise/LICENSE-RNNoise-0.2.txt')]
        if (ROOT / '.gitattributes').exists():
            paths.append(Path('.gitattributes'))
        self.pinned = [p for p in paths if str(p).startswith(str(native))]
        for path in paths:
            destination = self.source / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / path).read_bytes())
        (self.source / 'unrelated-checkout-control.txt').write_bytes(b'unrelated text\n')
        self.git_environment = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        self.git('init', '--quiet', cwd=self.source)
        self.git('-c', 'core.autocrlf=false', 'add', '.', cwd=self.source)
        self.git('-c', 'user.name=Checkout Test', '-c', 'user.email=checkout@example.invalid',
                 'commit', '--quiet', '-m', 'Checkout fixture', cwd=self.source)
        self.git('-c', 'core.autocrlf=true', 'clone', '--quiet', '--no-hardlinks',
                 '--config', 'core.autocrlf=true', str(self.source), str(self.checkout))

    def git(self, *arguments, cwd=None):
        return subprocess.run(['git', *arguments], cwd=cwd, env=self.git_environment,
                              check=True, capture_output=True).stdout

    def test_windows_checkout_preserves_every_pinned_source_byte_and_component_hash(self):
        model = Path('clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream/src/rnn_data.c')
        self.assertEqual(hashlib.sha256((self.checkout / model).read_bytes()).hexdigest(),
                         'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95')
        for path in self.pinned:
            with self.subTest(source=str(path)):
                self.assertEqual((self.checkout / path).read_bytes(), (self.source / path).read_bytes())
                self.assertEqual(self.git('show', f'HEAD:{path.as_posix()}', cwd=self.checkout),
                                 (self.source / path).read_bytes())
        sidecars = self.checkout / 'release'
        sidecars.mkdir()
        import shutil
        shutil.copyfile(self.checkout / 'tools/audio/release_source/lock.json', sidecars / 'rnnoise-engine.json')
        shutil.copyfile(self.checkout / 'tools/audio/runtime_assets/rnnoise/LICENSE-RNNoise-0.2.txt', sidecars / 'LICENSE-RNNoise-0.2.txt')
        component = write_audio_component(sidecars, root=self.checkout, platform='windows')
        self.assertEqual(component['model_id'], 'rnnoise-release-v0.2')
        self.assertEqual(component['version'], '0.2')

    def test_checkout_control_proves_autocrlf_is_enabled_outside_pinned_sources(self):
        self.assertEqual(self.git('config', '--get', 'core.autocrlf', cwd=self.checkout).strip(), b'true')
        self.assertEqual((self.checkout / 'unrelated-checkout-control.txt').read_bytes(),
                         b'unrelated text\r\n')
