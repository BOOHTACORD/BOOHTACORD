import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import call, patch

from .stack import Stack


class StackLinuxRuntimeTests(unittest.TestCase):
    def make_stack(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        return Stack(root, root)

    def test_api_runs_in_owned_linux_container_with_private_attachment_tmpfs(self):
        stack = self.make_stack()
        with patch.object(stack, 'container') as container, \
                patch('tools.qa.client_lifecycle.stack.ready'):
            stack.start_api()

        args = container.call_args.args
        self.assertEqual(args[:2], ('api', stack.image))
        self.assertIn(('--tmpfs', '/attachments:rw,noexec,nosuid,nodev,uid=65532,gid=65532,mode=700,size=4g'),
                      list(zip(args, args[1:])))
        self.assertIn(('--publish', '127.0.0.1:4820:8080'), list(zip(args, args[1:])))
        self.assertIn('ATTACHMENTS_DIRECTORY=/attachments', args)
        self.assertIn('API_ADDR=0.0.0.0:8080', args)
        self.assertEqual(stack.api, stack.owner+'-api')

    def test_migrations_run_against_database_service_in_owned_network(self):
        stack = self.make_stack()
        with patch('tools.qa.client_lifecycle.stack.run') as run:
            stack.migrate()

        command = run.call_args.args
        self.assertEqual(command[:4], ('docker', 'run', '--rm', '--network'))
        self.assertEqual(command[4], stack.owner)
        self.assertIn('--entrypoint', command)
        self.assertIn('/migrate', command)
        self.assertIn(stack.image, command)
        self.assertIn(f'DATABASE_URL={stack.environment["DATABASE_URL"]}', command)

    def test_bootstrap_passes_the_disposable_password_over_container_stdin(self):
        stack = self.make_stack()
        with patch('tools.qa.client_lifecycle.stack.run') as run:
            stack.bootstrap()

        self.assertIn('-i', run.call_args.args)
        self.assertEqual(run.call_args.kwargs['input'], stack.password+'\n')

    def test_admin_reference_fixture_seeds_nineteen_non_login_members(self):
        stack = self.make_stack()
        with patch('tools.qa.client_lifecycle.stack.run') as run:
            stack.seed_admin_members()

        command = run.call_args.args
        self.assertEqual(command[:5], ('docker', 'exec', stack.owner+'-db', 'psql', '-U'))
        self.assertIn('generate_series(1, 19)', command[-1])
        self.assertIn('qa_member_', command[-1])
        self.assertIn('qa-screenshot-fixture-disabled', command[-1])
        self.assertIs(run.call_args.kwargs['stdout'], subprocess.DEVNULL)

    def test_close_removes_api_container_before_image_and_network(self):
        stack = self.make_stack()
        stack.resources = [('network', stack.owner), ('image', stack.image),
                           ('container', stack.owner+'-api')]
        stack.api = stack.owner+'-api'
        with patch('tools.qa.client_lifecycle.stack.remove_owned') as remove:
            stack.close()

        self.assertEqual(remove.call_args_list, [
            call(stack.owner+'-api', stack.owner, 'container'),
            call(stack.image, stack.owner, 'image'),
            call(stack.owner, stack.owner, 'network'),
        ])
        self.assertEqual(stack.resources, [])
        self.assertIsNone(stack.api)
