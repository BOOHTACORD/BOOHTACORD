from contextlib import contextmanager
import unittest
from unittest.mock import patch
from . import firefox_audio


class FirefoxAudioTests(unittest.TestCase):
    def test_linux_ci_installs_dependencies_and_runs_with_private_sink(self):
        @contextmanager
        def sink():
            yield {'PULSE_SERVER': 'unix:/private/test.sock'}
        with patch.object(firefox_audio.sys, 'platform', 'linux'), \
             patch.dict(firefox_audio.os.environ, {'GITHUB_ACTIONS': 'true'}), \
             patch.object(firefox_audio.shutil, 'which', return_value='/usr/bin/test'), \
             patch.object(firefox_audio, 'isolated_sink', sink), \
             patch.object(firefox_audio, 'run') as run:
            firefox_audio.main()
        calls = run.call_args_list
        self.assertIn('--with-deps', calls[0].args)
        self.assertIn('pulseaudio', calls[1].args)
        self.assertEqual(calls[2].kwargs['env']['PULSE_SERVER'], 'unix:/private/test.sock')
        self.assertIn('rnnoise.browser.spec.ts', calls[2].args)
