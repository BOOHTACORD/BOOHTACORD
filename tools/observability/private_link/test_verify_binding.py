import unittest
from .verify_binding import verify


class BindingTests(unittest.TestCase):
    def test_only_expected_up_bridge_owns_address(self):
        data = [{'ifname': 'br-0123456789ab', 'flags': ['UP', 'BROADCAST'],
                 'addr_info': [{'family': 'inet', 'local': '172.19.0.1', 'scope': 'global'}]}]
        verify('br-0123456789ab', '172.19.0.1', data)
        for changed in (
            [{'ifname': 'eth0', 'flags': ['UP'], 'addr_info': data[0]['addr_info']}],
            [{'ifname': 'br-0123456789ab', 'flags': [], 'addr_info': data[0]['addr_info']}],
            [{'ifname': 'br-0123456789ab', 'flags': ['UP'], 'addr_info': [{'family': 'inet', 'local': '172.30.0.1', 'scope': 'global'}]}],
            [],
        ):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                verify('br-0123456789ab', '172.19.0.1', changed)

    def test_runtime_preflight_rejects_public_or_invalid_bind_without_network(self):
        for address in ('0.0.0.0', '167.233.56.32', '127.0.0.1', 'localhost', '::1'):
            with self.subTest(address=address), self.assertRaises(ValueError):
                verify('br-0123456789ab', address, [])
