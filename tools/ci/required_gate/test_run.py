import contextlib
import io
import json
import os
import unittest
from unittest.mock import patch
from .run import main
from .test_validation import JOBS, fixture
from tools.ci.select_changes.selection import dependency_map


class GateCommandTests(unittest.TestCase):
    def test_real_current_map_digest_and_expected_docs_skips(self):
        needs = fixture([])
        needs['changes']['outputs']['map_sha256'] = dependency_map()[1]
        with patch.dict(os.environ, {'CI_NEEDS': json.dumps(needs), 'CI_JOBS': json.dumps(JOBS)}):
            self.assertEqual(main(), 0)

    def test_invalid_json_or_failure_is_nonzero_and_does_not_echo_input(self):
        for value in ['private-token-invalid-json', json.dumps({'private-user': 'private-token'})]:
            output = io.StringIO()
            with patch.dict(os.environ, {'CI_NEEDS': value, 'CI_JOBS': json.dumps(JOBS)}), contextlib.redirect_stdout(output):
                self.assertEqual(main(), 1)
            self.assertNotIn('private', output.getvalue())
