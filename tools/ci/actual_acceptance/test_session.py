"""Namespaces differ between runs and cleanup never accepts a foreign owner."""
import unittest
from unittest.mock import patch
from . import session


class SessionTests(unittest.TestCase):
    def test_case_owner_is_unique_and_source_bound(self):
        first=session.identity('a'*40,'lifecycle',{'GITHUB_RUN_ID':'12','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'runtime'})
        second=session.identity('a'*40,'lifecycle',{'GITHUB_RUN_ID':'13','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'runtime'})
        self.assertNotEqual(first['owner'],second['owner'])
        self.assertRegex(first['owner'],r'^qa-client-[0-9a-f]{16}$')

    def test_cleanup_uses_exact_owner_filter_and_cannot_remove_foreign_resource(self):
        with patch.object(session,'output',side_effect=['a'*64,'foreign-owner']),patch.object(session,'run') as run:
            with self.assertRaises(ValueError):session.cleanup('qa-client-'+'a'*16)
            run.assert_not_called()

    def test_shared_or_personal_host_is_refused_before_docker(self):
        with patch.dict('os.environ',{},clear=True),patch.object(session,'output') as output:
            with self.assertRaises(ValueError):session.hosted()
            output.assert_not_called()
