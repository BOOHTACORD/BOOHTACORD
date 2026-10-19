import unittest
from .rollback import eligible,require_branch


class ConfigurationRollbackTests(unittest.TestCase):
    def test_product_data_and_historical_evidence_never_enter_config_restore_set(self):
        for path in ('backend/main.go','clients/flutter/lib/main.dart','evidence/ci/proof.json','backlog/tasks.yaml','.env','db/volume','tools/verify/contracts/screen_viewer_presence.ps1','tools/qa/local_features/features.json'):
            with self.subTest(path=path):self.assertFalse(eligible(path))
        for path in ('.github/workflows/ci.yaml','tools/ci/required_gate/run.py','tools/verify/workflows/required.py','Taskfile.yml'):
            self.assertTrue(eligible(path))

    def test_current_master_or_foreign_branch_is_not_an_apply_target(self):
        for name in ('master','release/foo','codex/issue401-cutover-readiness'):
            with self.assertRaises(ValueError):require_branch(name)
        require_branch('codex/workflow-rollback-01234567')

    def test_real_git_candidate_preserves_product_and_evidence(self):
        import subprocess,tempfile
        from pathlib import Path
        from unittest.mock import patch
        from . import rollback,readiness
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve()
            def git(*args):return subprocess.check_output(['git','-c','core.hooksPath=/dev/null','-c','commit.gpgsign=false',*args],cwd=root,text=True,stderr=subprocess.DEVNULL).strip()
            git('init','-q');git('config','user.name','CI fixture');git('config','user.email','ci@example.invalid')
            for name,value in [('.github/workflows/ci.yaml','name: ci-required\n# old\n'),('backend/main.go','old'),('evidence/test.json','old')]:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(value)
            git('add','.github','backend','evidence');git('commit','-qm','checkpoint');checkpoint=git('rev-parse','HEAD')
            (root/'.github/workflows/ci.yaml').write_text('name: ci-required\n# new\n')
            (root/'backend/main.go').write_text('product feature preserved');(root/'evidence/test.json').write_text('historical evidence preserved')
            (root/'tools/ci').mkdir(parents=True);(root/'tools/ci/demo.py').write_text('new CI driver')
            git('add','.github','backend','evidence','tools');git('commit','-qm','migration plus unrelated product feature')
            with patch.object(rollback,'ROOT',root),patch.object(readiness,'ROOT',root),patch.object(rollback,'policy',return_value={'rollback_checkpoints':[checkpoint]}):
                plan=rollback.preview(checkpoint);git('switch','-c',plan['candidate_branch']);rollback.apply(plan)
            self.assertIn('# old',(root/'.github/workflows/ci.yaml').read_text())
            self.assertEqual('product feature preserved',(root/'backend/main.go').read_text())
            self.assertEqual('historical evidence preserved',(root/'evidence/test.json').read_text())
            self.assertFalse((root/'tools/ci/demo.py').exists())
