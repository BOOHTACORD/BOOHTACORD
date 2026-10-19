"""Host account credentials stay outside guests; failed jobs cannot retain workers."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from . import worker


class WorkerTests(unittest.TestCase):
    def test_cpu_sets_partition_the_eight_cpu_host_without_overlap(self):
        allocations = []
        for slot in ('1', '2', '3', '4'):
            start, end = map(int, worker.CPUSETS[slot].split('-'))
            allocations.append(set(range(start, end + 1)))
        self.assertEqual([3, 3, 1, 1], list(map(len, allocations)))
        self.assertEqual(set(range(8)), set().union(*allocations))
        self.assertEqual(8, sum(map(len, allocations)))

    def test_idle_retirement_never_treats_busy_or_failed_api_as_success(self):
        with patch.object(worker.subprocess, 'run', return_value=SimpleNamespace(returncode=1)) as run:
            self.assertFalse(worker.retire_idle(42))
        self.assertEqual(worker.subprocess.DEVNULL, run.call_args.kwargs['stdout'])
        self.assertEqual(worker.subprocess.DEVNULL, run.call_args.kwargs['stderr'])
        with patch.object(worker.subprocess, 'run', return_value=SimpleNamespace(returncode=0)):
            self.assertTrue(worker.retire_idle(42))

    def test_job_assigned_near_idle_deadline_gets_a_full_execution_window(self):
        active = {'ActiveState': 'active', 'ExecMainStatus': '0'}
        complete = {'ActiveState': 'inactive', 'ExecMainStatus': '0'}
        with patch.object(worker, 'agent_state', side_effect=[active, complete]), \
                patch.object(worker, 'retire_idle', return_value=False) as retire, \
                patch.object(worker.time, 'monotonic', side_effect=[0, 21601, 21601]), \
                patch.object(worker.time, 'sleep'):
            self.assertFalse(worker.monitor_agent([], 42))
        retire.assert_called_once_with(42)

    def test_idle_guest_is_retired_atomically_before_local_destruction(self):
        with patch.object(worker, 'agent_state', return_value={'ActiveState': 'active'}), \
                patch.object(worker, 'retire_idle', return_value=True), \
                patch.object(worker.time, 'monotonic', side_effect=[0, 21601]):
            self.assertTrue(worker.monitor_agent([], 42))

    def test_busy_or_unavailable_registration_cannot_extend_the_bound_forever(self):
        with patch.object(worker, 'agent_state', return_value={'ActiveState': 'active'}), \
                patch.object(worker, 'retire_idle', return_value=False) as retire, \
                patch.object(worker.time, 'monotonic', side_effect=[0, 21601, 21601, 43202]), \
                patch.object(worker.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'maximum execution time'):
                worker.monitor_agent([], 42)
        retire.assert_called_once_with(42)

    def test_transient_observation_failure_does_not_destroy_running_job(self):
        with patch.object(worker, 'command', side_effect=[
                worker.OperationError('Runner operation failed: lxc exec status -15'),
                'ActiveState=active\nExecMainStatus=0\n']) as command, patch.object(worker.time, 'sleep'):
            self.assertEqual('active', worker.agent_state(['lxc', 'exec', 'guest', '--', 'systemctl'])['ActiveState'])
        self.assertEqual(2, command.call_count)
        self.assertTrue(all('show' in call.args[0] for call in command.call_args_list))

    def test_observation_does_not_swallow_shutdown_or_retry_indefinitely(self):
        with patch.object(worker, 'command', side_effect=RuntimeError('Worker shutdown')) as command:
            with self.assertRaisesRegex(RuntimeError, 'Worker shutdown'): worker.agent_state([])
        self.assertEqual(1, command.call_count)
        with patch.object(worker, 'command', side_effect=worker.OperationError('transport failed')) as command, \
                patch.object(worker.time, 'sleep'):
            with self.assertRaises(worker.OperationError): worker.agent_state([])
        self.assertEqual(3, command.call_count)

    def test_boot_waits_for_system_bus_before_registration_is_allowed(self):
        with patch.object(worker, 'command', side_effect=[
                'Failed to connect to bus: No such file or directory\n', 'starting\n', 'running\n']) as command, \
                patch.object(worker.time, 'sleep'):
            worker.wait_for_boot('boohtacord-ci-1')
        self.assertEqual(3, command.call_count)

    def test_unready_guest_cannot_obtain_a_github_runner_identity(self):
        calls = []
        def command(args, **options):
            calls.append(args)
            if 'is-system-running' in args: return 'starting\n'
            return ''
        with patch.object(worker, 'command', command), patch.object(worker, 'verify_base'), \
                patch.object(worker.time, 'monotonic', side_effect=[0, 0, 121]), patch.object(worker.time, 'sleep'):
            with self.assertRaises(RuntimeError): worker.cycle('1')
        self.assertFalse(any(row[:2] == ['gh', 'api'] for row in calls))
        self.assertIn(['lxc', 'delete', '--force', 'boohtacord-ci-1'], calls)

    def test_completed_guest_service_is_destroyed_before_another_job(self):
        calls = []
        def command(args, **options):
            calls.append(args)
            if 'is-system-running' in args: return 'running\n'
            if args[:4] == ['gh', 'api', '--method', 'POST']:
                return json.dumps({'runner': {'id': 44}, 'encoded_jit_config': 'secret-jit'})
            if args[:2] == ['lxc', 'exec'] and 'show' in args:
                return 'ActiveState=inactive\nExecMainStatus=0\n'
            return ''
        with tempfile.TemporaryDirectory() as temporary, patch.object(worker, 'command', command), \
                patch.object(worker, 'RUNTIME', Path(temporary)), patch.object(worker, 'verify_base'):
            worker.cycle('2')
            self.assertFalse(list(Path(temporary).iterdir()))
        self.assertIn(['lxc', 'delete', '--force', 'boohtacord-ci-2'], calls)
        self.assertIn('limits.cpu=3-5', next(row for row in calls if row[:2] == ['lxc', 'copy']))
        self.assertIn(['gh', 'api', '--method', 'DELETE', worker.API + '/44'], calls)

    def test_metadata_slot_cannot_receive_a_heavy_linux_job(self):
        payloads, clones = [], []
        def command(args, **options):
            if 'is-system-running' in args: return 'running\n'
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
        self.assertIn('limits.cpu=6-6', clones[0])

    def test_rejects_an_unknown_slot_before_creating_resources(self):
        with patch.object(worker, 'command') as command:
            with self.assertRaises(ValueError):
                worker.cycle('builder')
            command.assert_not_called()

    def test_cleanup_after_failed_execution_and_token_not_in_arguments(self):
        calls = []
        def command(args, **options):
            calls.append(args)
            if 'is-system-running' in args: return 'running\n'
            if args[:3] == ['gh', 'api', '--method']:
                return json.dumps({'runner': {'id': 42}, 'encoded_jit_config': 'secret-jit'})
            if args[:3] == ['lxc', 'exec', 'boohtacord-ci-1'] and 'show' in args:
                return 'ActiveState=failed\nExecMainStatus=1\n'
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
        self.assertIn('systemctl', execution)
        service = Path(worker.__file__).with_name('guest-runner.service').read_text()
        self.assertIn('SupplementaryGroups=docker', service)
        self.assertIn('User=runner', service)
        self.assertTrue(any('show' in row and 'boohtacord-agent' in row for row in calls))

    def test_refuses_privileged_or_host_mounted_base(self):
        safe = {'expanded_config': {'security.privileged': 'false', 'security.idmap.isolated': 'true',
                           'limits.cpu': '3', 'limits.memory': '4GiB'},
                'expanded_devices': {'root': {'type': 'disk', 'path': '/', 'pool': 'boohtacord-ci'},
                            'eth0': {'type': 'nic', 'network': 'boohtaci0'}}}
        with patch.object(worker, 'command', return_value=json.dumps(safe)):
            worker.verify_base()
        safe['expanded_devices']['credentials'] = {'type': 'disk', 'path': '/host', 'source': '/root'}
        with patch.object(worker, 'command', return_value=json.dumps(safe)):
            with self.assertRaises(ValueError): worker.verify_base()
