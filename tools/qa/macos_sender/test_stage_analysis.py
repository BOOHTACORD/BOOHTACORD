import unittest
from .stage_analysis import counter_rates
class RateProofTests(unittest.TestCase):
 def test_missing_reset_and_backward_clock_are_unknown(self):
  rows=[{'at_ms':0,'accepted_frames':10},{'at_ms':1000,'accepted_frames':40},{'at_ms':2000,'accepted_frames':None},{'at_ms':3000,'accepted_frames':1},{'at_ms':2500,'accepted_frames':20},{'at_ms':4000,'accepted_frames':10}]
  self.assertEqual(counter_rates(rows,'accepted_frames'),[30.0])
