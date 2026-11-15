"""Web/backend selective retries preserve original, fully validated evidence."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .parts import read_parts
from tools.ci.backend_gates import results as backend
from tools.ci.backend_gates.test_results import fixture as backend_fixture
from tools.ci.web_suites import fan_in as web, catalog
from tools.ci.web_suites.test_fan_in import fixture as web_fixture

SOURCE = 'a' * 40
ENV = {'GITHUB_ACTIONS': 'true', 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '2', 'WEB_NAMESPACE': 'web'}


class ProfilePartsTests(unittest.TestCase):
    def test_selective_retry_and_negative_evidence_for_both_complete_profile_sets(self):
        for kind, fixture, validate, execution, names in (
                ('backend', backend_fixture, backend.validate, backend.execution, backend.PROFILES),
                ('web', web_fixture, web.validate_results, catalog.execution, catalog.PROFILES)):
            with self.subTest(kind=kind), patch.dict(os.environ, ENV), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary).resolve(); needs, rows = fixture(); original = []
                retried = 'load' if kind == 'backend' else 'sfu-network'
                for row in rows:
                    profile = row['profile']; attempt = '2' if profile == retried else '1'
                    row['execution']['run_attempt'] = attempt
                    prefix = 'backend-part-' if kind == 'backend' else 'web-part-web-'
                    archive = root / (prefix + SOURCE + '-123-' + attempt + '-' + profile)
                    archive.mkdir(); file = archive / (profile + '.json')
                    file.write_text(json.dumps(row), encoding='utf-8'); original.append((file, file.read_bytes()))
                parts, attempts = read_parts(root, kind, SOURCE, execution(), names)
                summary = validate(SOURCE, needs, parts, attempts=attempts)
                self.assertEqual(summary['status'], 'PASS')
                self.assertEqual(attempts[retried], '2')
                self.assertEqual(set(attempts.values()), {'1', '2'})
                for file, raw in original: self.assertEqual(file.read_bytes(), raw)
                for field, value in [('status', 'FAIL'), ('source_revision', 'b' * 40), ('operations', [])]:
                    bad = copy.deepcopy(parts); bad[0][field] = value
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        validate(SOURCE, needs, bad, attempts=attempts)
                bad = copy.deepcopy(parts); bad[0]['execution']['run_id'] = '124'
                with self.assertRaises(ValueError): validate(SOURCE, needs, bad, attempts=attempts)
                bad = copy.deepcopy(parts); bad[0]['execution']['run_attempt'] = '3'
                with self.assertRaises(ValueError): validate(SOURCE, needs, bad, attempts=attempts)
                bad_needs = copy.deepcopy(needs); next(iter(bad_needs.values()))['result'] = 'failure'
                with self.assertRaises(ValueError): validate(SOURCE, bad_needs, parts, attempts=attempts)
                with self.assertRaises(ValueError): validate(SOURCE, needs, parts)
