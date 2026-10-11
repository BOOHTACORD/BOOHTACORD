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
