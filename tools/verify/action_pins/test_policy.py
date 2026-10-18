import json
from pathlib import Path
import tempfile
import unittest
from .policy import check_source, normalized


class ActionPinsTests(unittest.TestCase):
    def setUp(self):
        self.pins = {'actions/checkout': {'commit': 'a' * 40, 'reviewed_ref': 'v4'}}

    def test_exact_approved_commit_normalizes_only_for_policy_inspection(self):
        source = 'steps:\n  - uses: actions/checkout@' + 'a' * 40 + ' # v4\n'
        check_source(source, self.pins)
        self.assertIn('uses: actions/checkout@v4', normalized(source, self.pins))

    def test_tags_branches_unknown_or_unapproved_commits_fail(self):
        for action in ['actions/checkout@v4', 'actions/checkout@master',
                       'actions/checkout@' + 'b' * 40, 'foreign/action@' + 'a' * 40]:
            with self.subTest(action=action), self.assertRaises(ValueError):
                check_source('  - uses: ' + action, self.pins)

    def test_local_workflow_references_remain_local(self):
        source = 'uses: ./.github/workflows/ci-backend.yaml'
        self.assertEqual(normalized(source, self.pins), source)

    def test_raw_url_and_expression_actions_are_rejected(self):
        for action in ['${{ inputs.action }}', 'docker://private/image:latest', 'https://private.example/action']:
            with self.assertRaises(ValueError):
                check_source('uses: ' + action, self.pins)

    def test_yaml_flow_quoted_and_block_uses_are_also_checked(self):
        for source in ["steps: [{uses: 'actions/checkout@v4'}]",
                       "steps:\n  - 'uses': actions/checkout@v4",
                       "steps:\n  - uses: >-\n      actions/checkout@v4"]:
            with self.subTest(source=source), self.assertRaises(ValueError):
                check_source(source, self.pins)

    def test_invalid_yaml_is_not_an_unchecked_action(self):
        with self.assertRaises(ValueError): check_source('steps: [', self.pins)
