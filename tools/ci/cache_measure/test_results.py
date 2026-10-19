"""A warm cache must still execute exactly the same real assertions."""
import copy
import unittest
from . import results


class CacheMeasureTests(unittest.TestCase):
    def rows(self):
        return [{'pair':p, 'temperature':t, 'seconds':2.0 if t=='cold' else 1.0,
                 'tests':['assertion-a', 'assertion-b'], 'status':'PASS'}
                for p in (1,2) for t in ('cold','warm')]

    def test_complete_comparable_pairs_have_explicit_sample_counts(self):
        value = results.summarize(self.rows())
        self.assertEqual(value['cold']['n'], 2)
        self.assertEqual(value['warm']['p50_seconds'], 1.0)
        self.assertEqual(value['tests'], ['assertion-a','assertion-b'])

    def test_missing_failed_skipped_duplicate_and_changed_tests_fail_closed(self):
        for mutation in ('missing','failed','skipped','duplicate','empty','different','time'):
            rows=self.rows()
            if mutation=='missing': rows.pop()
            if mutation=='failed': rows[1]['status']='FAIL'
            if mutation=='skipped': rows[1]['status']='SKIP'
            if mutation=='duplicate': rows[1]['temperature']='cold'
            if mutation=='empty': rows[1]['tests']=[]
            if mutation=='different': rows[1]['tests']=['assertion-a']
            if mutation=='time': rows[1]['seconds']=float('nan')
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): results.summarize(rows)

    def test_go_json_rejects_skip_failure_or_cached_test_results(self):
        good='{"Action":"pass","Test":"TestReal"}\n{"Action":"pass"}\n'
        self.assertEqual(results.go_tests(good),['TestReal'])
        for bad in (good+'{"Action":"skip"}\n', good+'{"Action":"fail"}\n',
                    '{"Action":"output","Output":"ok package (cached)"}\n', '{"Action":"pass"}\n'):
            with self.subTest(bad=bad), self.assertRaises(ValueError): results.go_tests(bad)

    def test_vitest_summary_requires_every_assertion_without_skips(self):
        good={'success':True,'numFailedTests':0,'numPendingTests':0,'numTodoTests':0,
              'numPassedTests':2,'numTotalTests':2,'testResults':[{'assertionResults':[
                  {'fullName':'one','status':'passed'},{'fullName':'two','status':'passed'}]}]}
        self.assertEqual(results.vitest_tests(good),['one','two'])
        for field in ('numFailedTests','numPendingTests','numTodoTests'):
            bad=copy.deepcopy(good);bad[field]=1
            with self.subTest(field=field), self.assertRaises(ValueError): results.vitest_tests(bad)
        bad=copy.deepcopy(good);bad['testResults'][0]['assertionResults'].pop()
        with self.assertRaises(ValueError): results.vitest_tests(bad)

    def test_missing_current_report_cannot_reuse_the_previous_observation(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch
        from . import run
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            calls=0
            report={'success':True,'numFailedTests':0,'numPendingTests':0,'numTodoTests':0,
                    'numPassedTests':1,'numTotalTests':1,'testResults':[{'assertionResults':[
                        {'fullName':'actual assertion','status':'passed'}]}]}
            def execute(command, cwd, env, timeout=300):
                nonlocal calls
                if command==['node','--version']: return 'v24.18.0',0.1
                if command[:2]==['go','env']: return 'go1.26.4',0.1
                if 'vitest' in command:
                    calls+=1
                    if calls==1:
                        path=Path(next(x.split('=',1)[1] for x in command if x.startswith('--outputFile=')))
                        path.write_text(json.dumps(report))
                    # Simulate a zero-exit wrapper that fails to produce a fresh report.
                    return '',0.1
                if command[:2]==['go','test']:
                    return '{"Action":"pass","Test":"TestReal"}\n{"Action":"pass"}\n',0.1
                return '',0.1
            with patch.object(run,'ROOT',root), patch.object(run,'approved_versions',return_value={'node':'24.18.0','go':'1.26.4'}), \
                 patch.object(run,'public_bytes',return_value=b'public'), patch.object(run,'payload',return_value={}), \
                 patch.object(run,'execute',side_effect=execute), \
                 patch.object(run.subprocess,'check_output',return_value='a'*40), patch.object(run.subprocess,'run'), \
                 patch.dict(run.os.environ,{'GITHUB_SHA':'a'*40}):
                with self.assertRaises(FileNotFoundError): run.main()
