"""The measurement workflow cannot replace original checks or publish releases."""
import copy
from pathlib import Path
import unittest
from unittest.mock import patch
import yaml
from tools.verify.action_pins.policy import normalized
from . import shadow_workflow

ROOT = Path(__file__).resolve().parents[3]


class ShadowWorkflowTests(unittest.TestCase):
    def document(self):
        return yaml.load(normalized((ROOT / '.github/workflows/flutter-ci-shadow.yaml').read_text()), Loader=yaml.BaseLoader)

    def test_committed_manual_control_preserves_original_checks_uploads_and_native_split(self):
        shadow_workflow.validate(self.document())

    def test_writes_automatic_triggers_ignored_failures_or_incomplete_samples_fail(self):
        for mutation in ('permissions', 'event', 'legacy', 'samples', 'fanin', 'artifact'):
            document = self.document()
            if mutation == 'permissions': document['permissions']['contents'] = 'write'
            elif mutation == 'event': document['on']['push'] = {}
            elif mutation == 'legacy': document['jobs']['legacy']['steps'].pop(8)
            elif mutation == 'samples': document['jobs']['profiles']['strategy']['matrix']['sample'] = ['1']
            elif mutation == 'fanin': document['jobs']['compare']['if'] = 'success()'
            else: document['jobs']['compare']['steps'][-1]['with']['if-no-files-found'] = 'ignore'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): shadow_workflow.validate(document)

    def test_control_template_must_match_the_immutable_original_workflow_hash(self):
        with patch.object(shadow_workflow, 'read_baseline_source', return_value='changed original workflow'), self.assertRaises(ValueError):
            shadow_workflow.definition()
