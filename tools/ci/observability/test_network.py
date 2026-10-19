import unittest
from urllib.error import HTTPError
from unittest.mock import Mock,patch
from .network import get


class MetadataRetryTests(unittest.TestCase):
    def test_only_transient_get_has_two_attempts(self):
        response=Mock();response.__enter__=Mock(return_value=response);response.__exit__=Mock(return_value=False);response.read.return_value=b'{}'
        opener=Mock();opener.open.side_effect=[HTTPError('https://api.github.com',503,'temporary',{},None),response]
        with patch('time.sleep'):self.assertEqual({},get('/actions/runs/101','token',opener))
        self.assertEqual(2,opener.open.call_count)

    def test_auth_missing_evidence_assertions_or_bad_json_are_not_retried(self):
        for error in (HTTPError('https://api.github.com',403,'auth',{},None),HTTPError('https://api.github.com',404,'missing',{},None),AssertionError('test failed')):
            opener=Mock();opener.open.side_effect=error
            with self.subTest(error=type(error).__name__),self.assertRaises(Exception):get('/actions/runs/101','token',opener)
            self.assertEqual(1,opener.open.call_count)

    def test_exhausted_transient_and_malformed_json_stay_failed(self):
        opener=Mock();opener.open.side_effect=HTTPError('https://api.github.com',503,'temporary',{},None)
        with patch('time.sleep'),self.assertRaises(RuntimeError):get('/actions/runs/101','token',opener)
        self.assertEqual(2,opener.open.call_count)
        response=Mock();response.__enter__=Mock(return_value=response);response.__exit__=Mock(return_value=False);response.read.return_value=b'invalid-json'
        opener=Mock();opener.open.return_value=response
        with self.assertRaises(ValueError):get('/actions/runs/101','token',opener)
        self.assertEqual(1,opener.open.call_count)
