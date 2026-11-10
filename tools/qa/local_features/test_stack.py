import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .stack import Stack

class StackTests(unittest.TestCase):
    def test_proxy_uses_private_service_dns_and_loopback_publish(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t); stack=Stack(root,root)
            with patch('tools.qa.client_lifecycle.stack.Stack.container') as create:
                stack.container('proxy','caddy:test','-v','fixture',network=False)
            config=(root/'Caddyfile').read_text()
            self.assertIn(stack.owner+'-api:8080',config)
            self.assertIn(stack.owner+'-sfu:4880',config)
            self.assertIn('127.0.0.1:4810:4810',create.call_args.args)
            self.assertTrue(create.call_args.kwargs['network'])

    def test_synthetic_catalog_mount_is_read_only_and_api_only(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t); stack=Stack(root,root); stack.qa_update_catalog=root/'catalog.json'
            with patch('tools.qa.local_features.stack.CriticalStack.container') as create:
                stack.container('api','fixture','--env','QA=1')
                args=create.call_args.args
                self.assertIn('--mount',args)
                self.assertIn(f'type=bind,src={stack.qa_update_catalog},dst=/qa-client-update/catalog.json,readonly',args)
                stack.container('db','fixture')
                self.assertNotIn('--mount',create.call_args.args)
