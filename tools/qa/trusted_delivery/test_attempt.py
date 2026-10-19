"""The real fault runner accepts only bounded named cases and immutable identities."""
from pathlib import Path
import unittest
from .attempt import inputs


class RealAttemptPlanTests(unittest.TestCase):
    def test_named_source_plan_cannot_redirect_transport_or_output_paths(self):
        plan={'source':'a'*40,'controller':'b'*40,'nonce':'c'*32}
        value=inputs('upgrade',plan)
        self.assertEqual(Path('/qa/private/incoming/upgrade'),value['incoming'])
        self.assertEqual(Path('/qa/private/drivers/upgrade'),value['temporary'])
        for name,change in [('../foreign',{}),('upgrade',{'nonce':'../bad'}),
                            ('upgrade',{'source':'master'}),('upgrade',{'incoming':'/etc'}),
                            ('upgrade',{'controller':'b'*7})]:
            with self.subTest(name=name,change=change),self.assertRaises(ValueError):
                inputs(name,{**plan,**change})
