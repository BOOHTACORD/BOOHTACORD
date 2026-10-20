"""Two browser observers must prove every actual install/retry/rollback boundary."""
from copy import deepcopy
import unittest
from .catalog import PHASES, validate_observations

BASELINE, NEXT = 'a'*40, 'b'*40


def rows():
    phases = [('baseline',BASELINE),('initial_maintenance',BASELINE),('initial',BASELINE),
              ('upgrade_maintenance',BASELINE),('upgraded',NEXT),('retry_maintenance',NEXT),
              ('retried',NEXT),('interrupted_maintenance',NEXT),('recovered',NEXT),
              ('recovery_retry_maintenance',NEXT),('recovery_retried',NEXT),
              ('rollback_maintenance',NEXT),('rolled_back',BASELINE),
              ('restore_maintenance',BASELINE),('restored',NEXT)]
    return [{'phase':phase,'browser':browser,'authenticated':True,'banner':phase.endswith('_maintenance'),
             'admission':503 if phase.endswith('_maintenance') else 201,
             'login_status':503 if phase.endswith('_maintenance') else 204 if phase in ('baseline','restored') else None,
             'permissions_sha256':'e'*64,'policy_unchanged':True,'member_admin_status':403,
             'admin_dm_history_status':404,'admin_dm_attachment_status':404,
             'revision':source} for phase,source in phases for browser in range(2)]


class DeliveryObserverTests(unittest.TestCase):
    def test_both_sources_same_sha_retries_and_approved_rollback_are_mandatory(self):
        self.assertEqual(15,len(PHASES))
        validate_observations(rows(),BASELINE,NEXT)

    def test_missing_duplicate_private_wrong_source_or_admission_cannot_pass(self):
        for mutation in ('missing','duplicate','private','source','banner','denial','positive','login','auth',
                         'member_admin','admin_dm','admin_file','policy','policy_numeric','policy_hash'):
            value=deepcopy(rows())
            if mutation=='missing':value.pop()
            if mutation=='duplicate':value[3]=value[2]
            if mutation=='private':value[0]['cookie']='private-canary'
            if mutation=='source':value[8]['revision']=BASELINE
            if mutation=='banner':value[2]['banner']=False
            if mutation=='denial':value[2]['admission']=201
            if mutation=='positive':value[0]['admission']=403
            if mutation=='login':value[2]['login_status']=204
            if mutation=='auth':value[0]['authenticated']=False
            if mutation=='member_admin':value[0]['member_admin_status']=200
            if mutation=='admin_dm':value[0]['admin_dm_history_status']=200
            if mutation=='admin_file':value[0]['admin_dm_attachment_status']=200
            if mutation=='policy':value[0]['policy_unchanged']=False
            if mutation=='policy_numeric':value[0]['policy_unchanged']=1
            if mutation=='policy_hash':value[2]['permissions_sha256']='0'*64
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                validate_observations(value,BASELINE,NEXT)
