"""A failed real command cannot produce a completed profile or leak its SFU."""
from contextlib import contextmanager
from types import SimpleNamespace
import unittest
from . import runner

SOURCE = 'a' * 40


class RunnerTests(unittest.TestCase):
    def boundary(self, fail=None):
        calls, states, ticks = [], [], iter((1.0, 2.0))
        def execute(*command, **options):
            calls.append(command)
            return SimpleNamespace(returncode=1 if fail and fail in command else 0)
        @contextmanager
        def sfu():
            states.append('start')
            try: yield
            finally: states.append('closed')
        def assets(root): states.append('assets')
        return calls, states, dict(executor=execute, assets_builder=assets,
                                  sfu_factory=sfu, clock=lambda: next(ticks))

    def test_one_locked_install_and_browser_preparation_per_profile(self):
        calls, states, options = self.boundary()
        row = runner.run_profile('browser-shell', SOURCE, **options)
        self.assertEqual(row['status'], 'PASS')
        self.assertEqual(calls.count(('npm', 'ci')), 1)
        self.assertEqual(sum('--with-deps' in c for c in calls), 1)
        self.assertEqual(states, ['assets'])
        self.assertIn('npm:test:accessibility', row['operations'])

    def test_fast_profile_has_no_browser_download_but_retains_build_and_units(self):
        calls, states, options = self.boundary()
        row = runner.run_profile('fast', SOURCE, **options)
        self.assertEqual(row['status'], 'PASS')
        self.assertEqual(calls.count(('npm', 'ci')), 1)
        self.assertFalse(any('--with-deps' in c for c in calls))
        self.assertIn(('npm', 'test'), calls)
        self.assertIn(('npm', 'run', 'build'), calls)

    def test_nonzero_exit_stops_and_closes_sfu_without_a_successful_report(self):
        calls, states, options = self.boundary(fail='test:audio:browser')
        with self.assertRaises(RuntimeError): runner.run_profile('sfu-network', SOURCE, **options)
        self.assertEqual(states, ['assets', 'start', 'closed'])
        self.assertFalse(any('tools.network.restricted.run' in c for c in calls))

    def test_unknown_profile_and_invalid_source_fail_before_install(self):
        for profile, source in [('unknown', SOURCE), ('fast', 'not-a-sha')]:
            calls, states, options = self.boundary()
            with self.subTest(profile=profile), self.assertRaises(ValueError):
                runner.run_profile(profile, source, **options)
            self.assertEqual(calls, [])
            self.assertEqual(states, [])
