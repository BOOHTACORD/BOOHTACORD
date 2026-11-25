"""Unsafe selectors, URLs and partial native observations cannot certify an update."""
import copy
import unittest
from .policy import target, validate_observation, require_hosted


def policy():
    return {'application_family':'boohtacord','catalog_revision':48,'platform':'windows',
            'distribution':'direct','channel':'stable','arch':'x64','state':'published',
            'target':{'release_id':'windows-direct-stable-r75','release_order':75,
                'version':'1.0.60','native_build':'96','summary':'Windows 1.0.60','priority':'normal',
                'release_notes_url':'https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.60',
                'action':{'kind':'open_download_page','url':'https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.60'}}}


class PolicyTests(unittest.TestCase):
    def test_only_real_newer_exact_windows_stable_selector_is_accepted(self):
        self.assertEqual(target(policy())['version'],'1.0.60')
        for key,value in [('platform','android'),('arch','arm64'),('state','disabled'),
                          ('catalog_revision',True),('application_family','other')]:
            row=policy();row[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):target(row)
        for key,value in [('version','1.0.32'),('native_build','46'),('release_order',46),
                          ('release_notes_url','https://github.com/attacker/repo/releases/tag/windows-v1.0.60')]:
            row=policy();row['target'][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):target(row)

    def test_action_cannot_send_old_client_elsewhere(self):
        for url in ['https://evil.test/download','http://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.60',
                    'https://github.com@evil.test/file','https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.61']:
            row=policy();row['target']['action']['url']=url
            with self.subTest(url=url),self.assertRaises(ValueError):target(row)

    def test_partial_or_wrong_native_observations_never_pass(self):
        row={'status':'PASS','mode':'old','version':'1.0.32','native_build':46,
             'version_visible':True,'offer_visible':True,'details_version_visible':True,
             'pid_scoped':True,'screenshot':'old-offer.png'}
        validate_observation(row,'old',policy()['target'])
        for key,value in [('status','FAIL'),('native_build',0),('version_visible',False),
                          ('pid_scoped',False),('offer_visible',False),('details_version_visible',False),
                          ('screenshot','../../user.png')]:
            changed=copy.deepcopy(row);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_observation(changed,'old',policy()['target'])

    def test_user_machine_is_rejected_before_installation(self):
        require_hosted({'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted'},'win32')
        for env,system in [({},'win32'),({'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'self-hosted'},'win32'),
                           ({'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted'},'linux')]:
            with self.assertRaises(RuntimeError):require_hosted(env,system)

    def test_current_requires_exact_installed_identity_and_no_false_offer(self):
        row={'status':'PASS','mode':'current','version':'1.0.60','native_build':96,
             'version_visible':True,'offer_visible':False,'incorrect_status_visible':False,
             'pid_scoped':True,'screenshot':'current-offer.png'}
        validate_observation(row,'current',policy()['target'])
        for key,value in [('version','1.0.59'),('native_build',95),('offer_visible',True),
                          ('incorrect_status_visible',True),('pid_scoped',False)]:
            changed=copy.deepcopy(row);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_observation(changed,'current',policy()['target'])
