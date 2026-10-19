"""Fresh observations bind health, running sources and persistent identities."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import observation

SOURCE = 'a' * 40


class InstalledObservationTests(unittest.TestCase):
    def test_volume_identity_contains_only_hashes_and_requires_each_owned_volume(self):
        values = []
        def docker(*args):
            name = args[-1]; values.append(name)
            return json.dumps([{'Name': name, 'Driver': 'local', 'Mountpoint': '/private/canary/' + name,
                                'CreatedAt': '2026-10-19T00:00:00Z', 'Scope': 'local'}])
        with patch.object(observation, 'docker', side_effect=docker): result = observation.volumes()
        self.assertEqual(set(observation.VOLUMES), set(result))
        self.assertTrue(all(len(v) == 64 for v in result.values()))
        self.assertEqual(4, len(values)); self.assertNotIn('canary', json.dumps(result))
        with patch.object(observation, 'docker', return_value='[]'), self.assertRaises(ValueError): observation.volumes()

    def test_missing_wrong_or_ambiguous_volume_identity_fails(self):
        for value in ('[]', '[{},{}]', '[{}]', json.dumps([{'Name': 'foreign'}])):
            with self.subTest(value=value), patch.object(observation, 'docker', return_value=value), self.assertRaises(ValueError):
                observation.volumes()

    def test_healthy_http_does_not_override_wrong_running_source_or_state(self):
        for changed in ('source', 'stopped', 'ambiguous'):
            def docker(*args):
                if args[0] == 'ps': return 'one\ntwo' if changed == 'ambiguous' else 'one'
                return json.dumps([{'State': {'Running': changed != 'stopped'}, 'Config': {'Labels': {
                    'org.opencontainers.image.revision': 'b' * 40 if changed == 'source' else SOURCE}}}])
            with patch.object(observation, 'docker', side_effect=docker), self.assertRaises(ValueError):
                observation.sources(SOURCE)

    def test_health_uses_local_tls_resolved_host_without_returning_host_or_body(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root/'.env').write_text('PASSWORD=private-canary\nPUBLIC_HOST=qa.example.test\n')
            with patch.object(observation, 'execute', return_value=b'') as execute:
                self.assertEqual('PASS', observation.health(root))
                argv = execute.call_args.args[0]
                self.assertIn('qa.example.test:443:127.0.0.1', argv)
                self.assertNotIn('--insecure', argv); self.assertNotIn('-k', argv)
                self.assertNotIn('private-canary', ' '.join(argv))
            (root/'.env').write_text('PUBLIC_HOST=one.test\nPUBLIC_HOST=two.test\n')
            with patch.object(observation, 'execute') as execute, self.assertRaises(ValueError): observation.health(root)
            execute.assert_not_called()

    def test_schema_fingerprint_hashes_catalog_only_and_never_product_rows(self):
        with patch.object(observation, 'docker', return_value='pg-one'), patch.object(observation, 'execute', return_value=b'f' * 64 + b'\n') as execute:
            self.assertEqual('f' * 64, observation.schema())
            argv = execute.call_args.args[0]; sql = argv[-1]
            self.assertIn('information_schema.columns', sql); self.assertIn('pg_constraint', sql)
            self.assertIn('PGOPTIONS=-c default_transaction_read_only=on', argv)
            self.assertNotIn('SELECT *', sql); self.assertNotIn('FROM messages', sql)
            self.assertNotIn('PGPASSWORD', ' '.join(argv))
