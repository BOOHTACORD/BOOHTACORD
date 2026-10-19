"""Low-cardinality artifact roles have complete immutable execution identities."""
import unittest
from .names import execution_name


class ArtifactNameTests(unittest.TestCase):
    def test_windows_packages_and_acceptance_names_include_source_run_and_attempt(self):
        for role, prefix in [('windows-distribution', 'BOOHTACORD-windows-x64'),
                             ('windows-installer', 'BOOHTACORD-windows-installer-x64'),
                             ('windows-recovery', 'desktop-recovery-windows'),
                             ('windows-acceptance', 'screen-setup-windows')]:
            with self.subTest(role=role):
                self.assertEqual(prefix + '-' + 'a' * 40 + '-123-2', execution_name(role, 'a' * 40, '123', '2'))

    def test_retry_source_and_run_cannot_collide(self):
        values={execution_name('windows-distribution', source, run, attempt)
                for source in ('a'*40, 'b'*40) for run in ('123', '124') for attempt in ('1', '2')}
        self.assertEqual(8, len(values))

    def test_unbounded_private_or_invalid_inputs_never_enter_an_artifact_name(self):
        valid=['windows-distribution', 'a'*40, '123', '1']
        for index, values in [(0, ['unknown', 'private-canary']), (1, ['a'*7, 'master', None]),
                              (2, ['0', '-1', True, '1\nprivate-canary']), (3, ['0', True, '1/2', '9'*30])]:
            for value in values:
                args=valid.copy();args[index]=value
                with self.subTest(index=index), self.assertRaises(ValueError) as error: execution_name(*args)
                self.assertNotIn('private-canary',str(error.exception))
