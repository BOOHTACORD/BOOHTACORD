"""The opt-in live installer stays separate from production trust and credentials."""
from pathlib import Path
import unittest
import yaml


class RuntimeWorkflowTests(unittest.TestCase):
    def test_actual_installation_is_explicit_manual_master_only_without_secrets(self):
        path = Path('.github/workflows/qa-compatible-rollback.yaml')
        value = yaml.safe_load(path.read_text())
        trigger = value.get('on', value.get(True))
        self.assertEqual({'workflow_dispatch'}, set(trigger))
        choice = trigger['workflow_dispatch']['inputs']['installation']
        self.assertEqual('boolean', choice['type'])
        self.assertIs(False, choice['default'])
        job = value['jobs']['rehearse']
        self.assertIn("github.ref == 'refs/heads/master'", job['if'])
        self.assertEqual(['self-hosted', 'linux', 'x64', 'boohtacord-ci-ephemeral'], job['runs-on'])
        self.assertNotIn('environment', job)
        self.assertNotIn('secrets.', path.read_text())
        self.assertEqual({'contents': 'read', 'actions': 'read'}, value['permissions'])
        steps = job['steps']
        live = next(s for s in steps if 'tools.qa.trusted_delivery.run ' in s.get('run', ''))
        legacy = next(s for s in steps if 'tools.qa.compatible_rollback.run ' in s.get('run', ''))
        self.assertIn('inputs.installation', live['if'])
        self.assertIn('!inputs.installation', legacy['if'])
        retained = next(s for s in steps if s.get('with', {}).get('path', '').find('build-*.json') >= 0)
        self.assertEqual('always()', retained['if'])
        self.assertIn('delivery.json', retained['with']['path'])
