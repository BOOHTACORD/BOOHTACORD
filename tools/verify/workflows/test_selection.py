import copy
import json
import unittest
from pathlib import Path
import yaml
from .selection import check


class WorkflowSelectionTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[3]
        self.document = yaml.load((root / '.github/workflows/ci.yaml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)

    def test_current_dependency_graph(self):
        check(self.document)

    def test_display_and_job_names_do_not_define_policy(self):
        jobs = self.document['jobs']
        jobs['arbitrary-native-build-name'] = jobs.pop('windows')
        aggregate = jobs['ci-required']
        aggregate['needs'] = ['arbitrary-native-build-name' if n == 'windows' else n for n in aggregate['needs']]
        env = aggregate['steps'][-1]['env']
        roles = json.loads(env['CI_JOBS'])
        roles['windows'] = 'arbitrary-native-build-name'
        env['CI_JOBS'] = json.dumps(roles)
        check(self.document)

    def test_missing_dependencies_or_wrong_component_fail(self):
        for changed in ({'needs': []}, {'if': "needs.changes.outputs.web == 'true'"}):
            invalid = copy.deepcopy(self.document)
            invalid['jobs']['windows'].update(changed)
            with self.assertRaises(ValueError):
                check(invalid)

    def test_contracts_cannot_be_hidden_by_path_selection(self):
        self.document['jobs']['contracts']['if'] = 'false'
        with self.assertRaises(ValueError):
            check(self.document)

    def test_required_aggregate_cannot_be_missing_conditional_or_incomplete(self):
        for update in [{'if': "success()"}, {'needs': ['changes', 'contracts']}, {'continue-on-error': 'true'}]:
            invalid = copy.deepcopy(self.document)
            invalid['jobs']['ci-required'].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                check(invalid)
        self.document['jobs'].pop('ci-required')
        with self.assertRaises(ValueError):
            check(self.document)

    def test_aggregate_cannot_interpolate_needs_as_shell_source(self):
        self.document['jobs']['ci-required']['steps'][-1]['run'] = 'python3 -c "${{ toJSON(needs) }}"'
        with self.assertRaises(ValueError):
            check(self.document)
