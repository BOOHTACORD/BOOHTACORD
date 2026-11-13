import unittest
import json
from pathlib import Path

from .selection import flutter_stage_result, flutter_unit_result, native_targets, stage_timeout


class SelectionTest(unittest.TestCase):
    def test_selected_features_add_native_targets_without_removing_smoke(self):
        catalog = {'connection': {'native_targets': ['integration_test/issue689_roster_test.dart']}}
        self.assertEqual(native_targets(catalog, ['connection']), [
            'integration_test/local_qa_test.dart', 'integration_test/issue689_roster_test.dart'])
        self.assertEqual(native_targets(catalog, []), ['integration_test/local_qa_test.dart'])

    def test_rejects_unknown_native_target(self):
        with self.assertRaises(ValueError):
            native_targets({'x': {'native_targets': ['arbitrary.dart']}}, ['x'])

    def test_voice_feature_selects_the_listener_and_roster_scenarios(self):
        catalog = json.loads(Path(__file__).with_name('features.json').read_text(encoding='utf8'))
        selected = native_targets(catalog, ['voice'])
        self.assertIn('integration_test/issue689_listener_test.dart', selected)
        self.assertIn('integration_test/issue689_roster_test.dart', selected)

    def test_connection_feature_runs_native_heartbeat_scenario(self):
        catalog = json.loads(Path(__file__).with_name('features.json').read_text(encoding='utf8'))
        self.assertIn('integration_test/issue689_heartbeat_test.dart', native_targets(catalog, ['connection_status']))

    def test_connection_feature_runs_native_envelope_scenario(self):
        catalog = json.loads(Path(__file__).with_name('features.json').read_text(encoding='utf8'))
        self.assertIn('integration_test/issue689_envelope_test.dart', native_targets(catalog, ['connection_status']))

    def test_required_update_feature_selects_the_real_native_scenario(self):
        catalog = json.loads(Path(__file__).with_name('features.json').read_text(encoding='utf8'))
        self.assertIn('integration_test/update_required_test.dart', native_targets(catalog, ['update_required']))

    def test_full_flutter_suite_has_a_bounded_longer_budget(self):
        self.assertEqual(stage_timeout('flutter-unit'), 3600)
        self.assertEqual(stage_timeout('android-runtime'), 1800)

    def test_skipped_or_missing_flutter_result_cannot_become_pass(self):
        self.assertEqual(flutter_unit_result(0, '01:00 +20 ~3: All tests passed!'), ('BLOCKED', 3))
        self.assertEqual(flutter_unit_result(0, '01:00 +20: All tests passed!'), ('PASS', 0))
        self.assertEqual(flutter_unit_result(0, 'test process stopped'), ('BLOCKED', None))
        self.assertEqual(flutter_unit_result(1, '01:00 +20: Some tests failed.'), ('FAIL', None))

    def test_component_captures_cannot_hide_flutter_skips(self):
        self.assertEqual(flutter_stage_result('flutter-component-captures', 0,
                         '02:00 +100 ~1: All tests passed!'), ('BLOCKED', 1))
        self.assertEqual(flutter_stage_result('flutter-unit', 0,
                         '01:00 +20: All tests passed!'), ('PASS', 0))
        self.assertEqual(flutter_stage_result('web-build', 0, ''), ('PASS', None))

    def test_web_test_stages_cannot_hide_skips_or_missing_summaries(self):
        self.assertEqual(flutter_stage_result('web-screen_profile', 0, '  1 skipped\n  18 passed (11.2s)'), ('BLOCKED', 1))
        self.assertEqual(flutter_stage_result('web-screen_profile', 0, '  18 passed (11.2s)'), ('PASS', 0))
        self.assertEqual(flutter_stage_result('web-screen_profile', 0, 'process stopped'), ('BLOCKED', None))
        self.assertEqual(flutter_stage_result('web-screen_profile', 1, '  1 failed'), ('FAIL', None))
        self.assertEqual(flutter_stage_result('web-unit', 0, ' Tests  3 skipped | 1817 passed (1820)'), ('BLOCKED', 3))
        self.assertEqual(flutter_stage_result('web-unit', 0, ' Tests  1820 passed (1820)'), ('PASS', 0))
        self.assertEqual(flutter_stage_result('web-unit', 0, ' Tests  0 skipped | 1820 passed (1820)'), ('PASS', 0))
        self.assertEqual(flutter_stage_result('web-screen_profile', 0, '  0 skipped\n  18 passed (11.2s)'), ('PASS', 0))
        self.assertEqual(flutter_stage_result('web-unit', 0, 'summary missing'), ('BLOCKED', None))
        self.assertEqual(flutter_stage_result('web-real-stack-393', 0, ''), ('PASS', None))


if __name__ == '__main__':
    unittest.main()
