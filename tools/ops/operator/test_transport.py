from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import transport


class TransportTests(unittest.TestCase):
    def test_exact_host_pin_and_no_forwarding_tty_password_or_user_config(self):
        with tempfile.TemporaryDirectory() as private,patch.object(transport,'execute') as execute:
            ssh=transport.SSH(private,dict(OPERATOR_SSH_PRIVATE_KEY='synthetic-key',DEPLOY_SERVER_IP='127.0.0.1',SSH_USER='qa'))
            ssh.command('boohtacord-operator-v1 audit '+'a'*40,30)
            args=execute.call_args.args[0]
            for option in ('StrictHostKeyChecking=yes','IdentitiesOnly=yes','ForwardAgent=no','RequestTTY=no'):self.assertIn(option,args)
            self.assertEqual(0o600,(Path(private)/'identity').stat().st_mode & 0o777)
            self.assertIn(transport.PIN,(Path(private)/'known_hosts').read_text())

    def test_unvalidated_identity_is_not_sent_to_ssh(self):
        with tempfile.TemporaryDirectory() as private,patch.object(transport,'execute') as execute:
            with self.assertRaises(ValueError):transport.SSH(private,dict(OPERATOR_SSH_PRIVATE_KEY='key',DEPLOY_SERVER_IP='host;id',SSH_USER='qa'))
            execute.assert_not_called()
