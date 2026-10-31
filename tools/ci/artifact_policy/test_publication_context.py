"""A capture converter must not publish from a personal or substituted checkout."""
import unittest
from . import publication_context


def environment():
    return {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted',
            'RUNNER_OS': 'Linux', 'GITHUB_REPOSITORY': 'BOOHTACORD/BOOHTACORD',
            'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '2',
            'WEB_NAMESPACE': 'web', 'FLUTTER_EVIDENCE_NAMESPACE': 'flutter'}


class PublicationContextTests(unittest.TestCase):
    def test_fresh_hosted_exact_checkout_returns_current_public_identity(self):
        calls = []
        def git(*args):
            calls.append(args)
            return 'a' * 40 if args == ('rev-parse', 'HEAD') else ''
        result = publication_context.checked(environment(), 'web', 'browser-shell', git=git)
        self.assertEqual({'repository': 'BOOHTACORD/BOOHTACORD', 'source_revision': 'a' * 40,
                          'run_id': '123', 'run_attempt': '2', 'namespace': 'web',
                          'component': 'web', 'profile': 'browser-shell', 'platform': 'linux'}, result)
        self.assertEqual([('rev-parse', 'HEAD'), ('status', '--porcelain', '--untracked-files=no')], calls)

    def test_local_self_hosted_fork_or_non_linux_input_is_rejected_before_git(self):
        cases = [('GITHUB_ACTIONS', 'false'), ('RUNNER_ENVIRONMENT', 'self-hosted'),
                 ('GITHUB_REPOSITORY', 'Egkurilov/BOOHTACORD'),
                 ('GITHUB_REPOSITORY', 'foreign/repo'), ('RUNNER_OS', 'macOS')]
        for field, value in cases:
            with self.subTest(field=field):
                env = environment(); env[field] = value
                with self.assertRaises(ValueError):
                    publication_context.checked(env, 'web', 'browser-voice',
                                                git=lambda *_: self.fail('Invalid context reached Git'))

    def test_missing_or_unbounded_execution_identity_is_not_published(self):
        for field, value in [('GITHUB_SHA', 'master'), ('GITHUB_RUN_ID', '0'),
                             ('GITHUB_RUN_ATTEMPT', '10000'), ('WEB_NAMESPACE', '../private'),
                             ('WEB_NAMESPACE', ''), ('GITHUB_RUN_ID', '1' * 21)]:
            with self.subTest(field=field):
                env = environment(); env[field] = value
                with self.assertRaises(ValueError):
                    publication_context.checked(env, 'web', 'browser-shell', git=lambda *_: 'a' * 40)

    def test_dirty_or_foreign_checkout_and_git_errors_never_produce_identity(self):
        for mutation in ('foreign', 'dirty', 'git-failure'):
            def git(*args):
                if mutation == 'git-failure': raise RuntimeError('git unavailable')
                if args[0] == 'rev-parse': return ('b' if mutation == 'foreign' else 'a') * 40
                return ' M tracked-file' if mutation == 'dirty' else ''
            with self.subTest(mutation=mutation), self.assertRaises((ValueError, RuntimeError)):
                publication_context.checked(environment(), 'web', 'browser-shell', git=git)

    def test_component_namespace_and_profile_are_fixed_by_reviewed_producer(self):
        git = lambda *args: 'a' * 40 if args[0] == 'rev-parse' else ''
        flutter = publication_context.checked(environment(), 'flutter', 'dart', git=git)
        self.assertEqual('flutter', flutter['namespace'])
        for component, profile in [('web', 'dart'), ('flutter', 'browser-voice'),
                                   ('web', 'fast'), ('physical', 'desktop')]:
            with self.subTest(component=component, profile=profile), self.assertRaises(ValueError):
                publication_context.checked(environment(), component, profile, git=git)

    def test_existing_flutter_namespace_capacity_is_preserved_without_expanding_web(self):
        from tools.ci.flutter_gates import source
        env = environment(); env['FLUTTER_EVIDENCE_NAMESPACE'] = 'f' * 48
        self.assertEqual('f' * 48, source.context(env)[3])
        git = lambda *args: 'a' * 40 if args[0] == 'rev-parse' else ''
        self.assertEqual('f' * 48, publication_context.checked(env, 'flutter', 'dart', git=git)['namespace'])
        env['FLUTTER_EVIDENCE_NAMESPACE'] += 'f'
        with self.assertRaises(ValueError): publication_context.checked(env, 'flutter', 'dart', git=git)
        env['WEB_NAMESPACE'] = 'w' * 41
        with self.assertRaises(ValueError): publication_context.checked(env, 'web', 'browser-shell', git=git)
