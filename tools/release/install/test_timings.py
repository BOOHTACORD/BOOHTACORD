"""Real rollout markers distinguish observed intervals from unavailable legacy data."""
import unittest
from . import timings


class RolloutIntervalTests(unittest.TestCase):
    def rows(self): return '\n'.join(f'{name} {1000+index*2}' for index,name in enumerate(timings.ORDER))+'\n'

    def test_complete_markers_measure_only_named_observed_intervals(self):
        result=timings.parse(self.rows())
        self.assertEqual('PASS',result['status']); self.assertEqual(1,result['resolution_seconds'])
        self.assertEqual(18,result['durations']['rollout_seconds'])
        self.assertEqual(12,result['durations']['maintenance_seconds'])
        self.assertEqual(2,result['durations']['migration_seconds'])
        self.assertEqual(result,timings.validate(result))

    def test_retained_runtime_without_markers_is_explicitly_unmeasured(self):
        self.assertEqual({'status':'NOT_AVAILABLE_LEGACY','events':[]},timings.parse(''))

    def test_partial_duplicate_reordered_negative_or_private_markers_never_become_pass(self):
        good=self.rows().splitlines()
        for raw in ('\n'.join(good[:-1]),'\n'.join([good[0],good[0],*good[2:]]),
                    '\n'.join(reversed(good)),self.rows().replace('1002','999'),
                    self.rows()+'private-canary 1020\n',self.rows().replace('1000','nan')):
            with self.subTest(raw=raw[:20]),self.assertRaises(ValueError) as error: timings.parse(raw)
            self.assertNotIn('canary',str(error.exception))

    def test_published_durations_must_be_recomputed_from_the_exact_events(self):
        result=timings.parse(self.rows()); result['durations']['maintenance_seconds']=0
        with self.assertRaises(ValueError): timings.validate(result)
        result=timings.parse(self.rows()); result['private']='private-canary'
        with self.assertRaises(ValueError): timings.validate(result)
