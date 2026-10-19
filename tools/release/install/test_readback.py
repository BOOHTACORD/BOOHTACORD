"""A receipt requires fresh source, health, schema and volume observations."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import readback

SOURCE = 'a' * 40
MIGRATIONS = {'0001.sql': 'b' * 64}


def manifest():
    return {'source_revision': SOURCE, 'compatibility': {'migrations': MIGRATIONS},
            'components': {n: {'index_digest': 'sha256:' + c * 64} for n,c in [('api', 'c'), ('web', 'd')]}}


def observed():
    return {'volumes': {name: 'e' * 64 for name in readback.observation.VOLUMES},
            'schema_sha256': 'f' * 64, 'health': 'PASS', 'sources': {'api': SOURCE, 'web': SOURCE}}


class FreshReadbackTests(unittest.TestCase):
    def test_fresh_evidence_is_source_bound_and_retained_without_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/SOURCE; root.mkdir()
            with patch.object(readback, 'collect', return_value=observed()):
                value = readback.record(root, manifest(), manifest(), observed())
            self.assertEqual('PASS', value['status']); self.assertEqual(SOURCE, value['source_revision'])
            self.assertEqual({'api': 'sha256:' + 'c' * 64, 'web': 'sha256:' + 'd' * 64}, value['running_images'])
            self.assertEqual('PASS', value['persistent_volumes'])
            self.assertTrue((root/'deployment-readback.json').is_file())

    def test_changed_volume_or_schema_without_new_migrations_fails_without_receipt(self):
        for changed in ('volume', 'schema'):
            after = observed()
            if changed == 'volume': after['volumes']['postgres-data'] = '0' * 64
            else: after['schema_sha256'] = '0' * 64
            with tempfile.TemporaryDirectory() as tmp, patch.object(readback, 'collect', return_value=after), self.assertRaises(ValueError):
                readback.record(Path(tmp), manifest(), manifest(), observed())
            self.assertFalse((Path(tmp)/'deployment-readback.json').exists())

    def test_additive_migration_can_change_schema_but_does_not_relax_volume_identity(self):
        previous = manifest(); previous['compatibility'] = {'migrations': {'0000.sql': '0' * 64}}
        after = observed(); after['schema_sha256'] = '0' * 64
        with tempfile.TemporaryDirectory() as tmp, patch.object(readback, 'collect', return_value=after):
            self.assertEqual('changed-with-migration-inventory', readback.record(Path(tmp), manifest(), previous, observed())['schema_relation'])

    def test_fresh_ssh_readback_cannot_accept_a_receipt_for_another_source_or_observation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/SOURCE; root.mkdir()
            with patch.object(readback, 'collect', return_value=observed()): readback.record(root, manifest(), manifest(), observed())
            with patch.object(readback, 'current_manifest', return_value=manifest()), patch.object(readback, 'collect', return_value=observed()):
                self.assertEqual(SOURCE, readback.fresh(root.parent, SOURCE, Path('public.pem'))['source_revision'])
            changed = observed(); changed['volumes']['caddy-data'] = '0'*64
            with patch.object(readback, 'current_manifest', return_value=manifest()), patch.object(readback, 'collect', return_value=changed), self.assertRaises(ValueError):
                readback.fresh(root.parent, SOURCE, Path('public.pem'))
            with patch.object(readback, 'current_manifest', return_value={**manifest(), 'source_revision': '0'*40}), self.assertRaises(ValueError):
                readback.fresh(root.parent, SOURCE, Path('public.pem'))

    def test_observed_rollout_intervals_survive_readback_but_malformed_metrics_fail(self):
        from . import timings
        measured=timings.parse(''.join(f'{name} {1000+i}'+'\n' for i,name in enumerate(timings.ORDER)))
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/SOURCE;root.mkdir()
            with patch.object(readback,'collect',return_value=observed()):
                result=readback.record(root,manifest(),manifest(),observed(),rollout=measured)
                self.assertEqual(measured,result['rollout'])
            with patch.object(readback,'current_manifest',return_value=manifest()),patch.object(readback,'collect',return_value=observed()):
                self.assertEqual(measured,readback.fresh(root.parent,SOURCE,Path('public.pem'))['rollout'])
            malformed={**measured,'private':'canary'}
            with patch.object(readback,'collect',return_value=observed()),self.assertRaises(ValueError):
                readback.record(root,manifest(),manifest(),observed(),rollout=malformed)
