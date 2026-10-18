import unittest
from pathlib import Path
from .proxy import configuration


class ProxyTests(unittest.TestCase):
    def test_real_production_forward_auth_is_preserved_before_sfu(self):
        root=Path(__file__).resolve().parents[3]
        result=configuration((root/'deploy/caddy/Caddyfile').read_text(), 'qa-client-123', '/owned/site')
        self.assertIn('log_skip @rtc', result)
        self.assertIn('uri /internal/media-admission', result)
        self.assertIn('header_up X-Forwarded-Uri {uri}', result)
        self.assertLess(result.index('forward_auth qa-client-123-api:8080'), result.index('reverse_proxy qa-client-123-sfu:4880'))
        self.assertIn('https://localhost:4830', result)
        self.assertNotIn('reverse_proxy web:80', result)

    def test_owner_and_site_are_not_caddy_injection(self):
        source=(Path(__file__).resolve().parents[3]/'deploy/caddy/Caddyfile').read_text()
        for owner,site in [('foreign\nlog {}','/owned/site'),('qa-client-123','/site\nlog {}')]:
            with self.assertRaises(ValueError): configuration(source,owner,site)

    def test_missing_admission_fails_closed(self):
        with self.assertRaises(ValueError): configuration('reverse_proxy livekit:7880','qa-client-123','/owned/site')
