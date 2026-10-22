import copy
import unittest

from tools.observability.dashboard_delivery.publish import payload, canonical, Grafana, NoRedirect


class DashboardPublicationTest(unittest.TestCase):
    def setUp(self):
        self.source = {'uid': 'boohtacord-traces', 'id': None, 'version': 1, 'title': 'BOOHTACORD | Traces', 'panels': []}
        self.current = {'dashboard': {**self.source, 'id': 42, 'version': 13},
                        'meta': {'folderUid': 'existing-private-folder', 'provisioned': False, 'canSave': True}}

    def test_update_uses_existing_id_folder_and_optimistic_version(self):
        result = payload(self.source, self.current, 13)
        self.assertEqual(result['dashboard']['version'], 13)
        self.assertEqual(result['dashboard']['id'], 42)
        self.assertEqual(result['folderUid'], 'existing-private-folder')
        self.assertFalse(result['overwrite'])
        self.assertEqual(self.source['version'], 1)

    def test_refuses_concurrent_change_uid_or_provisioned_overwrite(self):
        with self.assertRaises(ValueError):
            payload(self.source, self.current, 12)
        for field, value in (('provisioned', True), ('canSave', False)):
            changed = copy.deepcopy(self.current)
            changed['meta'][field] = value
            with self.assertRaises(ValueError):
                payload(self.source, changed, 13)
        with self.assertRaises(ValueError):
            payload({**self.source, 'uid': 'unrelated'}, self.current, 13)

    def test_readback_compares_configuration_without_server_version_fields(self):
        self.assertEqual(canonical(self.source), canonical(self.current['dashboard']))
        changed = {**self.source, 'panels': [{'id': 1, 'targets': []}]}
        self.assertNotEqual(canonical(self.source), canonical(changed))

    def test_credentials_cannot_follow_redirects_or_enter_url(self):
        for origin in ('http://grafana.example.test', 'https://u:p@grafana.example.test', 'https://grafana.example.test/unrelated'):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                Grafana(origin, 'synthetic', 'synthetic')
        with self.assertRaises(RuntimeError):
            NoRedirect().redirect_request(None, None, 302, '', {}, 'https://elsewhere.example.test')


if __name__ == '__main__':
    unittest.main()
