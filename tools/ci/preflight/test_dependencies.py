import unittest

from tools.ci.preflight.dependencies import web_dependency_change


class DependencyTest(unittest.TestCase):
    def test_only_dependency_sections_trigger_lock_review(self):
        before = '{"name":"x","dependencies":{"a":"1"}}'
        self.assertFalse(web_dependency_change(before, '{"name":"y","dependencies":{"a":"1"}}'))
        self.assertTrue(web_dependency_change(before, '{"name":"x","dependencies":{"a":"2"}}'))
        self.assertTrue(web_dependency_change(before, '{"name":"x","devDependencies":{"b":"1"}}'))

    def test_bad_manifest_is_not_a_clean_result(self):
        with self.assertRaises(ValueError):
            web_dependency_change('{}', 'invalid')


if __name__ == '__main__':
    unittest.main()
