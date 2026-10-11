import tempfile
import subprocess
import unittest
from pathlib import Path
from .policy import local_api, covered_features, validate_selection, changed_paths
from .report import verdict

class PolicyTests(unittest.TestCase):
    def test_only_owned_https_api(self):
        self.assertEqual(local_api('https://localhost:4810/api/v1'), 'https://localhost:4810/api/v1')
        self.assertEqual(local_api('https://10.0.2.2:4810/api/v1'), 'https://10.0.2.2:4810/api/v1')
        for url in ['https://v.bootybay.ru/api/v1', 'http://localhost:4810/api/v1',
                    'https://localhost:4810@evil.test/api/v1', 'https://localhost:4810/api/v1?token=x']:
            with self.assertRaises(ValueError): local_api(url)

    def test_changed_feature_must_be_selected(self):
        catalog = {'voice': {'paths': ['clients/web/src/voice/*']},
                   'auth': {'paths': ['clients/flutter/lib/src/screens/auth*']}}
        self.assertEqual(covered_features(['clients/web/src/voice/VoiceDock.vue'],catalog), {'voice'})
        with self.assertRaises(ValueError):
            validate_selection(['clients/web/src/voice/VoiceDock.vue'],catalog,{'auth'})
        validate_selection(['clients/web/src/voice/VoiceDock.vue'],catalog,{'voice'})

    def test_tests_alone_do_not_complete_visual_acceptance(self):
        self.assertEqual(verdict([{'status':'PASS'}],0), 'NOT_RUN_VISUAL')
        self.assertEqual(verdict([{'status':'PASS'}],4), 'REVIEW_REQUIRED')
        self.assertEqual(verdict([{'status':'FAIL'}],4), 'FAIL')
        self.assertEqual(verdict([{'status':'BLOCKED'}],4), 'BLOCKED')
        self.assertEqual(verdict([],4), 'NOT_RUN')

    def test_new_untracked_feature_cannot_bypass_coverage(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            def git(*args):
                subprocess.run(['git',*args],cwd=root,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            git('init','-q')
            (root/'README').write_text('fixture')
            git('add','README')
            git('-c','user.name=QA','-c','user.email=qa@example.invalid','commit','-qm','fixture')
            new=root/'clients/web/src/new_feature/view.ts'
            new.parent.mkdir(parents=True);new.write_text('export {}')
            paths=changed_paths(root,'HEAD')
            self.assertIn('clients/web/src/new_feature/view.ts',paths)
            with self.assertRaises(ValueError):validate_selection(paths,{},set())

if __name__ == '__main__': unittest.main()
