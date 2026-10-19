"""Every disposable smoke resource uses the same daemon and journal owner."""
import unittest
from unittest.mock import patch
from . import smoke


class SmokeOwnershipTests(unittest.TestCase):
    def test_container_and_network_creation_receive_owner_and_scope_labels(self):
        environment={'DOCKER_CONFIG':'/private/build-client','BOOHTACORD_BUILD_OWNER':'a'*32}
        for args in (('run','--rm','test-image'),('create','test-image'),('network','create','release-smoke-fixture')):
            with self.subTest(args=args), patch.object(smoke.subprocess,'check_output',return_value='id\n') as call:
                smoke.docker(*args,environment=environment)
                command=call.call_args.args[0]
                self.assertIn('org.boohtacord.builder.owner='+'a'*32,command)
                self.assertIn('org.boohtacord.builder.scope=smoke',command)
                self.assertEqual(environment,call.call_args.kwargs['env'])

    def test_database_readiness_uses_the_same_explicit_daemon_environment(self):
        environment={'DOCKER_CONFIG':'/private/build-client'}
        with patch.object(smoke.subprocess,'run') as call:
            call.return_value.returncode=0
            smoke.wait_database('owned-db',environment=environment)
        self.assertEqual(environment,call.call_args.kwargs['env'])
