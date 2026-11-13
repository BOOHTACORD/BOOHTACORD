import json
import unittest
from pathlib import Path

from .policy import validate_selection


class Issue689CoverageTests(unittest.TestCase):
    def test_web_permission_changes_require_connection_acceptance(self):
        catalog = json.loads(Path(__file__).with_name('features.json').read_text(encoding='utf-8'))
        changed = ['clients/web/src/authorization/permission_store.ts',
                   'clients/web/src/authorization/permission_store.spec.ts']
        with self.assertRaises(ValueError):
            validate_selection(changed, catalog, set())
        validate_selection(changed, catalog, {'connection_status'})


if __name__ == '__main__':
    unittest.main()
