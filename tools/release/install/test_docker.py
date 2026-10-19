import json
import unittest
from pathlib import Path
from unittest.mock import patch
from .docker import deploy


class WriterPreflightTests(unittest.TestCase):
    def test_second_running_writer_blocks_rollout_before_mutation(self):
        with patch('tools.release.install.docker.docker', side_effect=[
                json.dumps({'services': {'api': {}}}), 'one\ntwo']), \
                patch('tools.release.install.docker.subprocess.run') as rollout:
            with self.assertRaises(ValueError):
                deploy(Path('/retained'), {'components': {}})
            rollout.assert_not_called()

    def test_supported_writer_reaches_existing_guarded_rollout(self):
        with patch('tools.release.install.docker.docker', side_effect=[
                json.dumps({'services': {'api': {'deploy': {'replicas': 1}}}}), 'one']), \
                patch('tools.release.install.docker.subprocess.run') as rollout:
            deploy(Path('/retained'), {'components': {'api': {'index_digest': 'sha256:'+'a'*64}}})
            rollout.assert_called_once()
            self.assertEqual(rollout.call_args.kwargs['env']['API_IMAGE'], 'voice-platform-api@sha256:'+'a'*64)

    def test_real_owned_rollout_markers_are_read_and_temporary_file_is_removed(self):
        import tempfile
        from .timings import ORDER
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); script=root/'rollout.sh'
            lines=''.join(f'{name} {1000+i*2}\n' for i,name in enumerate(ORDER))
            script.write_text('printf \'%s\' \''+lines+'\' >> "$VOICE_PLATFORM_DELIVERY_PHASES"\nprintf \'%s\' "$VOICE_PLATFORM_DELIVERY_PHASES" > "$VOICE_PLATFORM_DIR/timing-path"\n')
            with patch('tools.release.install.docker.docker',side_effect=[json.dumps({'services':{'api':{}}}),'one']), \
                 patch('tools.release.install.docker.rollout_script',return_value=script):
                result=deploy(root,{'components':{}})
            self.assertEqual('PASS',result['status'])
            self.assertEqual(12,result['durations']['maintenance_seconds'])
            self.assertFalse(Path((root/'timing-path').read_text()).exists())

    def test_legacy_rollout_is_explicitly_unmeasured_and_partial_markers_fail(self):
        import tempfile
        for body in ('true\n','printf \'rollout_started 1000\\n\' >> "$VOICE_PLATFORM_DELIVERY_PHASES"\n'):
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp); script=root/'rollout.sh'; script.write_text(body)
                with patch('tools.release.install.docker.docker',side_effect=[json.dumps({'services':{'api':{}}}),'one']), \
                     patch('tools.release.install.docker.rollout_script',return_value=script):
                    if body=='true\n': self.assertEqual('NOT_AVAILABLE_LEGACY',deploy(root,{'components':{}})['status'])
                    else:
                        with self.assertRaises(ValueError): deploy(root,{'components':{}})
