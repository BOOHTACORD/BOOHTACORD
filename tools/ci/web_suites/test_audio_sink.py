import os
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch
from .audio_sink import isolated_sink


class AudioSinkTests(unittest.TestCase):
    def test_private_sink_is_ready_and_owned_process_is_stopped(self):
        process = MagicMock(); process.poll.return_value = None
        with patch('tools.ci.web_suites.audio_sink.subprocess.Popen', return_value=process) as start, \
             patch('tools.ci.web_suites.audio_sink.subprocess.run') as probe:
            probe.return_value.returncode = 0
            with isolated_sink() as env:
                socket = env['PULSE_SERVER'].removeprefix('unix:')
                self.assertNotEqual(env['PULSE_SERVER'], os.environ.get('PULSE_SERVER'))
                config = Path(socket).parent / 'null.pa'
                self.assertIn('module-null-sink', config.read_text())
                self.assertIn(socket, config.read_text())
                self.assertEqual(Path(env['PULSE_RUNTIME_PATH']).parent, Path(socket).parent)
                self.assertEqual(probe.call_args.kwargs['env']['PULSE_SERVER'], env['PULSE_SERVER'])
            start.assert_called_once(); process.terminate.assert_called_once(); process.wait.assert_called_once()

    def test_server_exit_is_a_failure_and_is_cleaned_up(self):
        process = MagicMock(); process.poll.return_value = 1
        with patch('tools.ci.web_suites.audio_sink.subprocess.Popen', return_value=process), \
             patch('tools.ci.web_suites.audio_sink.subprocess.run') as probe:
            probe.return_value.returncode = 1
            with self.assertRaisesRegex(RuntimeError, 'audio sink exited'):
                with isolated_sink(): pass
            process.wait.assert_called_once()
