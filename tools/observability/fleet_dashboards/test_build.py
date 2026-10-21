import json
import unittest
from .build import build, OUT


class ScopedDashboardsTest(unittest.TestCase):
    def test_generated_views_and_tenant_datasources(self):
        for name, doc in build().items():
            self.assertEqual(doc, json.loads((OUT / (name + '.json')).read_text()))
            self.assertEqual('installation', doc['templating']['list'][0]['name'])
            for panel in doc['panels']:
                for target in panel['targets']:
                    query = target.get('expr', target.get('query', ''))
                    if name != 'fleet':
                        self.assertIn('$installation', query)
                    if name == 'traces':
                        self.assertEqual('t-${installation}', panel['datasource']['uid'])
                        self.assertIn('resource.boohtacord.installation.id', query)
                    self.assertNotIn('user.name', query)
                    self.assertNotIn('user.label', query)


if __name__ == '__main__':
    unittest.main()
