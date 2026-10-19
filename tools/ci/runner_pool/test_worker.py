"""The runner token never reaches a command line; failed jobs cannot retain workers."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import worker


class WorkerTests(unittest.TestCase):
    def test_metadata_slot_cannot_receive_a_heavy_linux_job(self):
        payloads, clones = [], []
        def command(args, **options):
            if args[:3] == ['gh', 'api', '--method'] and args[3] == 'POST':
                payloads.append(json.loads(options['stdin']))
                return json.dumps({'runner': {'id': 43}, 'encoded_jit_config': 'secret-jit'})
            if args[:2] == ['lxc', 'copy']: clones.append(args)
            if args[:2] == ['lxc', 'exec']: raise RuntimeError('fixture failure')
            return ''
        with tempfile.TemporaryDirectory() as temporary, patch.object(worker, 'command', command), \
                patch.object(worker, 'RUNTIME', Path(temporary)), patch.object(worker, 'verify_base'):
            with self.assertRaises(RuntimeError): worker.cycle('3')
        self.assertEqual(['self-hosted', 'linux', 'x64', 'boohtacord-ci-meta'], payloads[0]['labels'])
        self.assertIn('limits.memory=512MiB', clones[0])
        self.assertIn('limits.cpu=1', clones[0])

    def test_rejects_an_unknown_slot_before_creating_resources(self):
        with patch.object(worker, 'command') as command:
            with self.assertRaises(ValueError):
                worker.cycle('builder')
            command.assert_not_called()

    def test_cleanup_after_failed_execution_and_token_not_in_arguments(self):
        calls = []
        def command(args, **options):
            calls.append(args)
            if args[:3] == ['gh', 'api', '--method']:
                return json.dumps({'runner': {'id': 42}, 'encoded_jit_config': 'secret-jit'})
            if args[:3] == ['lxc', 'exec', 'boohtacord-ci-1']:
                raise RuntimeError('fixture failure')
            return ''
        with tempfile.TemporaryDirectory() as temporary, patch.object(worker, 'command', command), \
                patch.object(worker, 'RUNTIME', Path(temporary)), \
                patch.object(worker, 'verify_base'):
            with self.assertRaises(RuntimeError):
                worker.cycle('1')
            self.assertFalse(list(Path(temporary).iterdir()))
        self.assertIn(['lxc', 'delete', '--force', 'boohtacord-ci-1'], calls)
        self.assertIn(['gh', 'api', '--method', 'DELETE', worker.API + '/42'], calls)
        self.assertNotIn('secret-jit', json.dumps(calls))
        execution = next(row for row in calls if row[:2] == ['lxc', 'exec'])
        self.assertIn('--disable-stdin', execution)
        self.assertEqual('non-interactive', execution[execution.index('--mode') + 1])

    def test_refuses_privileged_or_host_mounted_base(self):
        safe = {'expanded_config': {'security.privileged': 'false', 'security.idmap.isolated': 'true',
                           'limits.cpu': '2', 'limits.memory': '4GiB'},
                'expanded_devices': {'root': {'type': 'disk', 'path': '/', 'pool': 'boohtacord-ci'},
                            'eth0': {'type': 'nic', 'network': 'boohtaci0'}}}
        with patch.object(worker, 'command', return_value=json.dumps(safe)):
            worker.verify_base()
        safe['expanded_devices']['credentials'] = {'type': 'disk', 'path': '/host', 'source': '/root'}
        with patch.object(worker, 'command', return_value=json.dumps(safe)):
            with self.assertRaises(ValueError): worker.verify_base()
