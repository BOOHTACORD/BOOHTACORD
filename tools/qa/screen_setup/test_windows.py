import unittest
from unittest.mock import patch
from .windows import main
from .windows import validate_result


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
