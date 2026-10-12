import unittest
from pathlib import Path
from .stack import proxy_config
class StackConfigTests(unittest.TestCase):
    def test_every_proxy_port_uses_assigned_stack(self):
        config=proxy_config(Path('/qa/root'),'qa295298-owned')
        self.assertIn('https://localhost:4950',config)
        self.assertIn('reverse_proxy qa295298-owned-api:8080',config)
        self.assertNotIn('4810',config);self.assertNotIn('4820',config)
        self.assertIn('/qa/root/clients/web/dist',config)

    def test_proxy_can_bind_only_its_immutable_dist_copy(self):
        config=proxy_config(Path('/qa/root'),'qa295298-owned',dist=Path('/qa/root/.out/owned/web-dist'))
        self.assertIn('/qa/root/.out/owned/web-dist',config)
        self.assertNotIn('/qa/root/clients/web/dist',config)

    def test_parallel_web_stack_has_distinct_explicit_ports(self):
        from .stack import BaseStack, WEB_PORTS
        config=proxy_config(Path('/qa/root'),'qa295298-owned',ports=WEB_PORTS)
        self.assertIn('https://localhost:4960',config)
        self.assertNotIn('4950',config)
        stack=BaseStack(Path('/qa/root'),Path('/qa/work'),ports=WEB_PORTS)
        self.assertEqual(stack.environment['PUBLIC_ORIGIN'],'https://localhost:4960')
        self.assertEqual(stack.ports.api,4961)
        self.assertEqual((stack.ports.sfu_http,stack.ports.sfu_tcp,stack.ports.sfu_udp),(4996,4997,4999))
