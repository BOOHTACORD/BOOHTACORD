"""QA trust and SSH provisioning must refuse the host or a foreign Docker daemon."""
from pathlib import Path
import unittest
from .ssh_fixture import require_scope, configuration

OWNER='qa60-'+'a'*16


class SSHFixtureScopeTests(unittest.TestCase):
    def test_only_linux_owned_nested_scope_may_provision_fixture_trust(self):
        info={'Architecture':'x86_64','Labels':['boohtacord.qa.rollback='+OWNER]}
        require_scope(Path('/qa'),OWNER,info,platform='linux',uid=0)
        for work,owner,observed,platform,uid in [
                (Path('/tmp'),OWNER,info,'linux',0),(Path('/qa'),OWNER,info,'darwin',0),
                (Path('/qa'),OWNER,info,'linux',501),
                (Path('/qa'),OWNER,{**info,'Labels':[]},'linux',0),
                (Path('/qa'),'qa60-'+'b'*16,info,'linux',0)]:
            with self.subTest(work=work,platform=platform,uid=uid),self.assertRaises(ValueError):
                require_scope(work,owner,observed,platform=platform,uid=uid)

    def test_server_accepts_only_loopback_and_the_new_qa_operator_public_key(self):
        text=configuration()
        self.assertIn('ListenAddress 127.0.0.1',text)
        self.assertIn('PasswordAuthentication no',text)
        self.assertIn('PermitRootLogin no',text)
        self.assertIn('AllowUsers operator',text)
        self.assertNotIn('0.0.0.0',text)
