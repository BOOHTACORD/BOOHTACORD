"""Missing, stale, tampered or uncleared real-runtime receipts never pass."""
import copy
import unittest
from .validation import validate_result
from .plan import document
from .catalog import REPORTS


def fixture():
    return dict(schema_version=1,status='PASS',scope='automatic-PR-real-runtime',profile='sfu',
                source_revision='a'*40,run_id='123',run_attempt='2',job='runtime',owner='qa-client-'+'b'*16,
                map_sha256=document()[1],port_namespace='disposable-github-hosted-vm/123/2/runtime/'+'b'*16,
                physical_acceptance='NOT_RUN',release_acceptance='NOT_RUN',owned_resources_removed=True,
                reports=[dict(path=p,sha256='c'*64) for p in REPORTS['sfu']],captures=[],seconds=1)


class ValidationTests(unittest.TestCase):
    def test_exact_success(self):validate_result(fixture(),'sfu','a'*40,'123','2')

    def test_disposable_self_hosted_namespace_still_binds_the_same_job_and_owner(self):
        row=fixture()
        row['port_namespace']=row['port_namespace'].replace('disposable-github-hosted-vm/','disposable-self-hosted-guest/')
        validate_result(row,'sfu','a'*40,'123','2')
        for namespace in ('shared-host/123/2/runtime/'+'b'*16,
                          'disposable-self-hosted-guest/123/2/runtime/'+'c'*16):
            row['port_namespace']=namespace
            with self.assertRaises(ValueError):validate_result(row,'sfu','a'*40,'123','2')

    def test_stale_failed_or_missing_runtime_never_passes(self):
        for key,value in [('status','BLOCKED'),('source_revision','d'*40),('run_id','124'),('run_attempt','1'),
                          ('profile','next'),('map_sha256','d'*64),('owned_resources_removed',False),
                          ('reports',[]),('release_acceptance','PASS'),('physical_acceptance','PASS')]:
            row=copy.deepcopy(fixture());row[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_result(row,'sfu','a'*40,'123','2')
