import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class CutoverWorkflowTests(unittest.TestCase):
    def test_read_only_report_and_explicit_independent_review(self):
        docs={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}
        validate(docs)
        for change in ('master','permission','environment'):
            broken=copy.deepcopy(docs);job=broken['ci-cutover-review.yaml']['jobs']['review']
            if change=='master':job['if']='true'
            if change=='permission':broken['ci-cutover-review.yaml']['permissions']['contents']='write'
            if change=='environment':job['environment']=None
            with self.subTest(change=change),self.assertRaises(ValueError):validate(broken)
