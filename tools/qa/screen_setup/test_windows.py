import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from .windows import main
from .windows import validate_result, retain_failure


def fixture():
    return {'status': 'PASS', 'input': 'Win32 SendInput with exact foreground PID guard',
            'cases': [{'case': launcher + '-' + traversal, 'escape': True,
                       'focus_returned': True, 'same_connected_room_and_lease': True,
                       'mute_deafen_preserved': True, 'no_publication': True,
                       'footer_visible': True, 'quality_reachable': True,
                       'cancel_keyboard_reachable': True}
                      for launcher in ('header', 'dock') for traversal in ('initial', 'traversed')]}


class ResultTests(unittest.TestCase):
    def test_requires_complete_unique_actual_gui_matrix(self):
        validate_result(fixture())
        for change in ('missing', 'duplicate', 'mock_input', 'failed', 'false_observation', 'clipped_footer', 'unreachable_quality', 'unreachable_cancel'):
            value = fixture()
            if change == 'missing': value['cases'].pop()
            if change == 'duplicate': value['cases'][1] = value['cases'][0]
            if change == 'mock_input': value['input'] = 'WidgetTester'
            if change == 'failed': value['status'] = 'FAIL'
            if change == 'clipped_footer': value['cases'][0]['footer_visible'] = False
            if change == 'unreachable_quality': value['cases'][1].pop('quality_reachable')
            if change == 'unreachable_cancel': value['cases'][1]['cancel_keyboard_reachable'] = False
            if change == 'false_observation': value['cases'][0]['no_publication'] = False
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_result(value)

    def test_refuses_personal_or_non_windows_host_before_build(self):
        with patch('tools.qa.screen_setup.windows.sys.platform', 'darwin'):
            with self.assertRaises(RuntimeError): main()
        with patch('tools.qa.screen_setup.windows.sys.platform', 'win32'):
            with patch.dict('os.environ', {}, clear=True):
                with self.assertRaises(RuntimeError): main()
            with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'self-hosted'}, clear=True):
                with self.assertRaises(RuntimeError): main()


class FailureEvidenceTests(unittest.TestCase):
    def test_keeps_only_bounded_synthetic_failure_evidence(self):
        with TemporaryDirectory() as root:
            driver, destination = Path(root) / 'driver', Path(root) / 'retained'
            driver.mkdir(); destination.mkdir()
            (driver / 'failure.json').write_text(json.dumps({'status': 'FAIL',
                'step': 'header_initial_launcher', 'reason': 'launcher_not_visible',
                'private_configuration': 'must never be copied'}))
            (driver / 'private-client.log').write_text('must never be copied')
            result = retain_failure(driver, destination)
            self.assertEqual(result, {'status': 'FAIL', 'step': 'header_initial_launcher',
                                      'reason': 'launcher_not_visible'})
            self.assertNotIn('must never be copied', json.dumps(result))
            self.assertEqual({p.name for p in destination.iterdir()}, {'failure.json'})
            self.assertEqual(json.loads((destination / 'failure.json').read_text()),
                {'status': 'FAIL', 'step': 'header_initial_launcher', 'reason': 'launcher_not_visible'})
            (driver / 'failure.png').write_bytes(b'not a png')
            with self.assertRaises(ValueError): retain_failure(driver, destination)
            (driver / 'failure.png').write_bytes(b'\x89PNG\r\n\x1a\n' + b'0' * 2_000_000)
            with self.assertRaises(ValueError): retain_failure(driver, destination)
