from contextlib import contextmanager
import unittest
from unittest.mock import patch
from . import firefox_research


class FirefoxResearchTests(unittest.TestCase):
    def test_runs_both_graph_and_livekit_with_private_sink(self):
        @contextmanager
        def sink():
            yield {'PULSE_SERVER': 'unix:/private/test.sock'}
        @contextmanager
        def sfu():
            yield
        with patch.object(firefox_research, 'isolated_sink', sink), \
             patch.object(firefox_research, 'local_sfu', sfu), \
             patch.object(firefox_research, 'run') as run:
            firefox_research.main()
        self.assertEqual(len(run.call_args_list), 2)
        self.assertIn('deepfilter_loader.research.spec.ts', run.call_args_list[0].args)
        self.assertIn('deepfilter_livekit.research.spec.ts', run.call_args_list[1].args)
        self.assertEqual(run.call_args_list[1].kwargs['env']['PULSE_SERVER'], 'unix:/private/test.sock')
        self.assertEqual(run.call_args_list[1].kwargs['env']['RNNOISE_LIVEKIT_URL'], 'ws://127.0.0.1:17880')
        self.assertEqual(run.call_args_list[1].kwargs['env']['RNNOISE_LIVEKIT_API_KEY'], 'devkey')
