"""Production operator plans reject untrusted, ambiguous and unconfirmed inputs."""
import unittest
from .policy import request,remote_request


def context(**updates):
    return dict(dict(GITHUB_REPOSITORY='Egkurilov/BOOHTACORD',GITHUB_EVENT_NAME='workflow_dispatch',
                     GITHUB_REF='refs/heads/master',GITHUB_SHA='a'*40,GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1',
                     GITHUB_ACTOR_ID='42',EXPECTED_SOURCE='b'*40,OPERATOR_DRY_RUN='true'),**updates)


class PolicyTests(unittest.TestCase):
    def test_dry_run_reports_plan_without_authorizing_a_host_operation(self):
        self.assertTrue(request('audit',context())['dry_run'])

    def test_untrusted_source_missing_sha_and_rerun_cannot_authorize(self):
        for key,value in [('GITHUB_REPOSITORY','foreign/repo'),('GITHUB_EVENT_NAME','pull_request'),
                          ('GITHUB_REF','refs/heads/other'),('GITHUB_SHA','master'),('EXPECTED_SOURCE',''),
                          ('GITHUB_RUN_ATTEMPT','2')]:
            with self.subTest(key=key),self.assertRaises(ValueError):request('audit',context(**{key:value}))

    def test_mutation_needs_explicit_ack_and_rollback_needs_two_observers(self):
        env=context(OPERATOR_DRY_RUN='false',OPERATOR_CONFIRM='rollback-and-restore',PREVIOUS_SOURCE='c'*40,OBSERVERS_CONFIRMED='two-browsers-ready')
        self.assertEqual('mutation',request('rollback',env)['risk'])
        for key,value in [('OPERATOR_CONFIRM',''),('OBSERVERS_CONFIRMED','not-ready'),('PREVIOUS_SOURCE','b'*40)]:
            with self.subTest(key=key),self.assertRaises(ValueError):request('rollback',dict(env,**{key:value}))
        with self.assertRaises(ValueError):request('probe',context(OPERATOR_DRY_RUN='false'))

    def test_read_only_forced_command_rejects_any_mutation_or_shell(self):
        self.assertEqual(('audit','b'*40,None),remote_request('boohtacord-operator-v1 audit '+'b'*40))
        for text in ['bash -s','boohtacord-operator-v1 rollback '+'b'*40,'boohtacord-operator-v1 audit $(id)',
                     'boohtacord-operator-v1 preflight '+'b'*40+';id','boohtacord-operator-v1 sample '+'b'*40+' 121']:
            with self.subTest(text=text),self.assertRaises(ValueError):remote_request(text)
