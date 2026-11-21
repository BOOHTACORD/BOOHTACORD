import unittest
from types import SimpleNamespace
from unittest.mock import Mock
import urllib.error
import urllib.request
from .control import api_control


class OwnedControlTests(unittest.TestCase):
    def test_only_authorized_empty_post_can_restart_the_owned_api(self):
        stack = SimpleNamespace(owner='qa-client-' + 'a' * 16, restart=Mock())
        with api_control(stack) as endpoint:
            for path, token in [('', 'wrong'), ('?foreign=server', endpoint['token'])]:
                request = urllib.request.Request(endpoint['url'] + path, method='POST',
                    headers={'Authorization': 'Bearer ' + token}, data=b'')
                with self.assertRaises(urllib.error.HTTPError):
                    urllib.request.urlopen(request, timeout=3)
                stack.restart.assert_not_called()
            request = urllib.request.Request(endpoint['url'], method='POST', data=b'',
                headers={'Authorization': 'Bearer ' + endpoint['token']})
            with urllib.request.urlopen(request, timeout=3) as response:
                self.assertEqual(204, response.status)
            stack.restart.assert_called_once_with()

    def test_foreign_namespace_is_rejected_before_control_starts(self):
        with self.assertRaises(ValueError):
            with api_control(SimpleNamespace(owner='production', restart=Mock())):
                self.fail('Foreign fixture admitted')
