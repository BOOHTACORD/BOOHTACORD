"""Readback is part of installation success, not an optional later check."""
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
from . import run as installer

SOURCE = 'a' * 40


class InstallReadbackOrderTests(unittest.TestCase):
    def invoke(self, root, *, fail=False, stale=False):
        events=[]; bundle=root/'bundle'; bundle.write_bytes(b'x')
        manifest={'source_revision': SOURCE, 'compatibility': {'migrations': {}}}
        before={'volumes': {'opaque': 'b'*64}, 'schema_sha256': 'c'*64}
        args=SimpleNamespace(bundle=bundle, revision=SOURCE, sha256='d'*64, release_root=root,
                             public_key=root/'pub', environment=root/'env', expected_current_revision='e'*40)
        def extracted(_, destination, **kwargs): destination.mkdir()
        def checked(*args, **kwargs):
            events.append('fresh-readback')
            if fail: raise ValueError('health or identity differs')
        replacements={'sha256': lambda _: 'd'*64, 'docker': lambda *args: str(root),
                      'verify_bundle': lambda *args: manifest,
                      'current_manifest': lambda *args: {'source_revision': '0'*40 if stale else 'e'*40,
                                                        'compatibility': {'migrations': {}}},
                      'extract': extracted, 'compatible_upgrade': lambda *args: None,
                      'prepare_environment': lambda *args: events.append('environment'),
                      'load_images': lambda *args: events.append('load'), 'deploy': lambda *args: events.append('rollout'),
                      'verify_running': lambda *args: events.append('digests'),
                      'write_receipt': lambda *args: events.append('installed-receipt')}
        with ExitStack() as stack:
            for name, value in replacements.items(): stack.enter_context(patch.object(installer, name, value))
            stack.enter_context(patch.object(installer.subprocess, 'run'))
            stack.enter_context(patch.object(installer.observation, 'volumes', side_effect=lambda: events.append('before-volumes') or before['volumes']))
            stack.enter_context(patch.object(installer.observation, 'schema', return_value=before['schema_sha256']))
            stack.enter_context(patch.object(installer.readback, 'record', side_effect=checked))
            try: installer.install(args)
            except ValueError:
                if not (fail or stale): raise
        return events

    def test_observes_before_rollout_and_requires_fresh_readback_before_success(self):
        with tempfile.TemporaryDirectory() as tmp: events=self.invoke(Path(tmp))
        self.assertLess(events.index('before-volumes'), events.index('rollout'))
        self.assertLess(events.index('digests'), events.index('fresh-readback'))
        self.assertLess(events.index('fresh-readback'), events.index('installed-receipt'))

    def test_failed_fresh_health_or_volume_check_never_writes_success(self):
        with tempfile.TemporaryDirectory() as tmp: events=self.invoke(Path(tmp), fail=True)
        self.assertIn('rollout', events); self.assertNotIn('installed-receipt', events)

    def test_stale_expected_source_cannot_reach_observation_or_any_mutation(self):
        with tempfile.TemporaryDirectory() as tmp: events=self.invoke(Path(tmp), stale=True)
        self.assertEqual([], events)
