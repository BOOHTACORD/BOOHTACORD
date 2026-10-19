import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class OperatorWorkflowTests(unittest.TestCase):
    def setUp(self):self.docs={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}

    def test_current_explicit_diagnostics_and_mutation_matrix(self):validate(self.docs)

    def test_reader_cannot_get_deploy_key_writer_lock_or_automatic_trigger(self):
        for mode in ('key','lock','trigger','master'):
            docs=copy.deepcopy(self.docs);doc=docs['audit-attachment-volume.yaml'];job=doc['jobs']['audit']
            if mode=='key':job['steps'][-2]['env']['OPERATOR_SSH_PRIVATE_KEY']='${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}'
            if mode=='lock':job['concurrency']['group']='v-bootybay-production'
            if mode=='trigger':doc['on']['push']={}
            if mode=='master':job['if']='true'
            with self.subTest(mode=mode),self.assertRaises(ValueError):validate(docs)

    def test_probe_cannot_escape_non_cancellable_writer_lock_or_secret_environment(self):
        for mode in ('lock','cancel','environment','receipt'):
            docs=copy.deepcopy(self.docs);job=docs['qa11-preflight.yaml']['jobs']['probe']
            if mode=='lock':job['concurrency']['group']='another-queue'
            if mode=='cancel':job['concurrency']['cancel-in-progress']='true'
            if mode=='environment':job['environment']='production-diagnostics'
            if mode=='receipt':job['steps'][-1]['with']['path']='.out/'
            with self.subTest(mode=mode),self.assertRaises(ValueError):validate(docs)
