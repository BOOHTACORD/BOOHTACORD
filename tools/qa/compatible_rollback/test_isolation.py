import unittest
from .isolation import require_owned_daemon, require_owner, daemon_arguments, require_amd64_daemon, ownership_arguments


class IsolationTests(unittest.TestCase):
    def test_generated_files_return_to_caller_without_following_source_symlinks(self):
        arguments = ownership_arguments(1001, 123, ['current', 'previous', 'private', 'releases', 'ready.json'])
        self.assertIn('--no-dereference', arguments)
        self.assertIn('-P', arguments)
        self.assertEqual(arguments[-4:], ['1001:123', '/qa/private', '/qa/releases', '/qa/ready.json'])
        self.assertNotIn('/qa/current', arguments)
        self.assertNotIn('/qa/previous', arguments)
        for name in ('../foreign', '/foreign', '--reference=foreign', '.', '..'):
            with self.subTest(name=name), self.assertRaises(ValueError): ownership_arguments(1001, 123, [name])
        with self.assertRaises(ValueError): ownership_arguments(True, 123, ['private'])
        with self.assertRaises(ValueError): ownership_arguments(-1, 123, ['private'])

    def test_rejects_arm_daemon_before_attempting_rosetta_server_builds(self):
        for architecture in ('x86_64', 'amd64'):
            require_amd64_daemon({'Architecture': architecture})
        for architecture in ('aarch64', 'arm64', '', None):
            with self.subTest(architecture=architecture), self.assertRaises(ValueError):
                require_amd64_daemon({'Architecture': architecture})

    def test_explicit_daemon_command_prevents_entrypoint_adding_a_tcp_api(self):
        arguments = daemon_arguments('qa60-' + 'a' * 16)
        self.assertEqual(arguments[0], 'dockerd')
        self.assertEqual([a for a in arguments if a.startswith('--host=')], ['--host=unix:///var/run/docker.sock'])
        self.assertFalse(any('tcp://' in a for a in arguments))

    def test_dedicated_daemon_must_be_empty_and_have_the_run_identity(self):
        require_owned_daemon({'Labels': ['boohtacord.qa.rollback=qa60-' + 'a' * 16]}, [], 'qa60-' + 'a' * 16)
        for info, objects in [({'Labels': []}, []), ({'Labels': ['boohtacord.qa.rollback=other']}, []),
                              ({'Labels': ['boohtacord.qa.rollback=qa60-' + 'a' * 16]}, ['foreign'])]:
            with self.assertRaises(ValueError): require_owned_daemon(info, objects, 'qa60-' + 'a' * 16)

    def test_cleanup_refuses_foreign_objects_and_invalid_owner(self):
        owner = 'qa60-' + 'a' * 16
        require_owner({'boohtacord.qa.rollback': owner}, owner)
        for labels, run in [({}, owner), ({'boohtacord.qa.rollback': 'other'}, owner),
                            ({'boohtacord.qa.rollback': 'production'}, 'production')]:
            with self.assertRaises(ValueError): require_owner(labels, run)
