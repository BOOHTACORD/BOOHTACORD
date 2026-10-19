import unittest
from .manual_inputs import rollback_inputs


class ManualInputTests(unittest.TestCase):
    def test_exact_sources_and_observed_runs_are_not_fixed_historical_inputs(self):
        value=rollback_inputs(dict(CURRENT_SOURCE='a'*40,CURRENT_RUN='101',PREVIOUS_SOURCE='b'*40,PREVIOUS_RUN='102'))
        self.assertEqual(value['current'],dict(head='a'*40,run=101,equivalent_master='a'*40))

    def test_unverified_refs_shell_text_missing_runs_or_same_source_are_refused(self):
        env=dict(CURRENT_SOURCE='a'*40,CURRENT_RUN='101',PREVIOUS_SOURCE='b'*40,PREVIOUS_RUN='102')
        for key,value in [('CURRENT_SOURCE','master'),('CURRENT_SOURCE','$(id)'),('PREVIOUS_RUN',''),('PREVIOUS_SOURCE','a'*40)]:
            with self.subTest(key=key),self.assertRaises(ValueError):rollback_inputs(dict(env,**{key:value}))
