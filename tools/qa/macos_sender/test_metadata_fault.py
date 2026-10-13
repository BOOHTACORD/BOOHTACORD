import unittest
from .metadata_fault import fault_config
class MetadataFaultTests(unittest.TestCase):
 def test_only_owned_put_metadata_route_changes_tls_and_other_api_sfu_routes_are_preserved(self):
  owner='qa98325-'+'a'*16;original='localhost:5060 {\n  tls internal\n  handle_path /sfu* { reverse_proxy host.docker.internal:5063 }\n  handle /api/* {\n    reverse_proxy '+owner+'-api:8080\n  }\n}\n'
  failed=fault_config(original,owner,'failure');self.assertIn('method PUT',failed);self.assertIn('path /api/v1/voice/leases/*/screen-profile/v1',failed);self.assertIn('respond 503',failed);self.assertIn('tls internal',failed);self.assertIn('handle_path /sfu*',failed);self.assertIn('reverse_proxy '+owner+'-api:8080',failed)
  slow=fault_config(original,owner,'slow');self.assertIn('127.0.0.1:8081',slow);self.assertIn('header_up -Cookie',slow);self.assertIn('method POST',slow)
  for args in [(original,'foreign','failure'),(original,owner,'other'),(original.replace('tls internal','tls_insecure_skip_verify'),owner,'slow'),(original+original,owner,'failure')]:
   with self.assertRaises(ValueError):fault_config(*args)
