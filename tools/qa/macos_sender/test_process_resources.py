import unittest
from .process_resources import parse_resource_fields
class ResourceTests(unittest.TestCase):
 def test_cumulative_cpu_and_rss_not_instantaneous_percent(self):
  self.assertEqual(parse_resource_fields(' 01:02.50 200\n'),{'cpu_seconds':62.5,'rss_bytes':204800})
  self.assertEqual(parse_resource_fields('1:01:02.5 100')['cpu_seconds'],3662.5)
  self.assertIsNone(parse_resource_fields('unknown 100'))
  self.assertIsNone(parse_resource_fields('00:01.00 -5'))
