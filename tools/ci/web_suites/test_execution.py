"""Public execution identity isolates reusable callers, retries and profile names."""
import os
import unittest
from unittest.mock import patch
from . import catalog


class ExecutionTests(unittest.TestCase):
    def test_actual_action_identifiers_and_local_scope_are_distinct(self):
        with patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_RUN_ID='123',
                        GITHUB_RUN_ATTEMPT='2', WEB_NAMESPACE='shadow-new-1'):
            self.assertEqual(catalog.execution(),
                             {'run_id':'123', 'run_attempt':'2', 'namespace':'shadow-new-1'})
        with patch.dict(os.environ, GITHUB_ACTIONS='false', WEB_NAMESPACE='web'):
            self.assertEqual(catalog.execution()['run_id'], 'local')

    def test_unbounded_or_indirect_names_and_missing_action_metadata_are_rejected(self):
        for key, value in (('WEB_NAMESPACE','../parts'), ('WEB_NAMESPACE','*'),
                           ('WEB_NAMESPACE','a'*41), ('GITHUB_RUN_ID',''),
                           ('GITHUB_RUN_ATTEMPT','0')):
            env = dict(GITHUB_ACTIONS='true', GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1', WEB_NAMESPACE='web')
            env[key] = value
            with self.subTest(key=key), patch.dict(os.environ, env), self.assertRaises(ValueError):
                catalog.execution()
