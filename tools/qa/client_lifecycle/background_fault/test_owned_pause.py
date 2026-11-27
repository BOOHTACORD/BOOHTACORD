import unittest
from tools.qa.client_lifecycle.background_fault.owned_pause import pause_owned

OWNER = 'qa-client-0123456789abcdef'


class Docker:
    def __init__(self, label=OWNER, paused=False, lost_response=False):
        self.label, self.paused = label, paused
        self.lost_response = lost_response
        self.actions = []

    def __call__(self, *args):
        if args[1] == 'inspect':
            value = self.label if 'Labels' in args[3] else f'true {str(self.paused).lower()}'
            return value
        self.actions.append(args[1:])
        if args[1] == 'pause':
            self.paused = True
            if self.lost_response:
                raise RuntimeError('pause response lost')
        elif args[1] == 'unpause':
            self.paused = False
        return ''


class OwnedPauseTest(unittest.TestCase):
    def test_pauses_only_verified_owned_role_and_restores_it(self):
        docker = Docker()
        with pause_owned(OWNER, 'api', invoke=docker, check_local=lambda: None) as timeline:
            self.assertTrue(docker.paused)
            self.assertTrue(timeline['pause_verified'])
        self.assertFalse(docker.paused)
        self.assertTrue(timeline['restore_verified'])
        self.assertGreaterEqual(timeline['duration_seconds'], 0)
        self.assertEqual(docker.actions, [('pause', OWNER+'-api'), ('unpause', OWNER+'-api')])

    def test_fault_body_failure_still_restores_owned_sfu(self):
        docker = Docker()
        with self.assertRaisesRegex(ValueError, 'probe failed'):
            with pause_owned(OWNER, 'sfu', invoke=docker, check_local=lambda: None):
                raise ValueError('probe failed')
        self.assertFalse(docker.paused)
        self.assertEqual(docker.actions[-1], ('unpause', OWNER+'-sfu'))

    def test_lost_pause_reply_cannot_leave_container_paused(self):
        docker = Docker(lost_response=True)
        with self.assertRaisesRegex(RuntimeError, 'response lost'):
            with pause_owned(OWNER, 'api', invoke=docker, check_local=lambda: None):
                self.fail('must not enter an unverified fault')
        self.assertFalse(docker.paused)

    def test_foreign_or_prepaused_container_is_untouched(self):
        for docker in (Docker(label='foreign'), Docker(paused=True)):
            with self.subTest(docker=docker), self.assertRaises(ValueError):
                with pause_owned(OWNER, 'api', invoke=docker, check_local=lambda: None):
                    self.fail('must reject foreign or preexisting fault')
            self.assertEqual(docker.actions, [])

    def test_invalid_scope_or_remote_daemon_cannot_pause(self):
        for owner, role in [('production', 'api'), (OWNER, 'db'), (OWNER+';whoami', 'sfu')]:
            docker = Docker()
            with self.subTest(owner=owner, role=role), self.assertRaises(ValueError):
                with pause_owned(owner, role, invoke=docker, check_local=lambda: None):
                    self.fail('invalid scope')
            self.assertEqual(docker.actions, [])
        docker = Docker()
        def remote():
            raise ValueError('remote daemon')
        with self.assertRaisesRegex(ValueError, 'remote daemon'):
            with pause_owned(OWNER, 'api', invoke=docker, check_local=remote):
                self.fail('remote daemon')
        self.assertEqual(docker.actions, [])
