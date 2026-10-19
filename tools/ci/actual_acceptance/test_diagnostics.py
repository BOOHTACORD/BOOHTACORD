"""Only finite controller stage diagnostics can cross the private/public boundary."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock
from . import evidence


class FailureDiagnosticTests(unittest.TestCase):
    def test_failed_child_retains_stage_and_cleanup_without_becoming_green(self):
        from . import run as controller
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            def fail_child(*args, **kwargs):
                path = root/'.out/next-client-acceptance/controller-failure.json'
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps(dict(schema_version=1,status='FAIL',stage='capacity-stack-start',
                    capacity_profile='limited',failure_type='CalledProcessError')))
                return Mock(poll=Mock(return_value=1), returncode=1)
            env = {'GITHUB_SHA':'a'*40,'GITHUB_RUN_ID':'123','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'runtime'}
            with patch.dict('os.environ',env), patch.object(controller,'ROOT',root), \
                 patch.object(controller,'output',return_value='a'*40), \
                 patch.object(controller.subprocess,'run'), patch.object(controller.subprocess,'Popen',side_effect=fail_child), \
                 patch.object(controller.session,'hosted'), patch.object(controller.session,'cleanup',return_value=True), \
                 patch.object(controller,'stop_group'):
                with self.assertRaises(SystemExit): controller.execute('next','b'*40)
            report=json.loads((root/'.out/actual-acceptance/public/next/result.json').read_text())
            self.assertEqual(report['status'],'FAIL')
            self.assertTrue(report['owned_resources_removed'])
            self.assertEqual(len(report['diagnostics']),1)

    def test_failure_stage_is_retained_without_copying_private_logs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / '.out/next-client-acceptance/controller-failure.json'
            source.parent.mkdir(parents=True)
            row = dict(schema_version=1, status='FAIL', stage='capacity-stack-start',
                       capacity_profile='limited', failure_type='CalledProcessError')
            source.write_text(json.dumps(row))
            (source.parent/'private.log').write_text('never publish credentials or message text')
            destination = root/'public'; destination.mkdir()
            result = evidence.collect_failure(root, 'next', destination)
            self.assertEqual(len(result), 1)
            self.assertEqual(json.loads((destination/result[0]['path']).read_text()), row)
            self.assertFalse((destination/'private.log').exists())

    def test_missing_diagnostics_do_not_invent_a_root_cause(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve()
            self.assertEqual(evidence.collect_failure(root, 'next', root/'public'), [])

    def test_unknown_fields_stages_or_links_are_rejected(self):
        for case in ('extra', 'stage', 'large', 'link', 'duplicate'):
            with tempfile.TemporaryDirectory() as temporary, self.subTest(case=case):
                root = Path(temporary).resolve()
                source = root/'.out/next-client-acceptance/controller-failure.json'
                source.parent.mkdir(parents=True)
                row = dict(schema_version=1,status='FAIL',stage='capacity-stack-start',
                           capacity_profile='limited',failure_type='CalledProcessError')
                if case == 'extra': row['message'] = 'private body'
                if case == 'stage': row['stage'] = 'private body'
                source.write_text(json.dumps(row) if case != 'large' else 'x'*1025)
                if case == 'duplicate':
                    source.write_text('{"stage":"private body",'+json.dumps(row)[1:])
                if case == 'link':
                    target=root/'foreign.json'; source.rename(target); source.symlink_to(target)
                with self.assertRaises(ValueError): evidence.collect_failure(root, 'next', root/'public')
