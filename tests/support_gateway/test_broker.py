"""Provider status must cross the private broker without leaking provider bodies."""
import json
import subprocess
import unittest
from unittest.mock import patch
from support_gateway import broker


class BrokerTests(unittest.TestCase):
    def response(self,status,body):
        return subprocess.CompletedProcess([],0 if status<400 else 1,
            f'HTTP/2.0 {status} Synthetic\r\nContent-Type: application/json\r\n\r\n'.encode()+json.dumps(body).encode(),b'provider-private-canary')

    def test_status_is_preserved_without_provider_error_body(self):
        for status in (403,404,410,429,500):
            with self.subTest(status=status),patch.object(broker.subprocess,'run',return_value=self.response(status,{'message':'provider-private-canary'})):
                with self.assertRaises(broker.GitHubError) as caught:broker.api('repos/Egkurilov/BOOHTACORD/issues/17')
                self.assertEqual(status,caught.exception.status)
                self.assertNotIn('private-canary',str(caught.exception))

    def test_successful_response_parses_included_headers(self):
        with patch.object(broker.subprocess,'run',return_value=self.response(200,{'number':17})):
            self.assertEqual({'number':17},broker.api('repos/Egkurilov/BOOHTACORD/issues/17'))

    def test_only_absence_with_accessible_repository_means_deleted(self):
        for status in (404,410):
            with self.subTest(status=status),patch.object(broker,'api',side_effect=[broker.GitHubError(status),{'private':False}]) as api:
                self.assertEqual({'exists':False},broker.execute({'operation':'issue','issue':17},'/unused'))
                self.assertEqual('repos/Egkurilov/BOOHTACORD',api.call_args.args[0])
        for status in (403,429,500,None):
            with self.subTest(status=status),patch.object(broker,'api',side_effect=broker.GitHubError(status)):
                with self.assertRaises(broker.GitHubError):broker.execute({'operation':'issue','issue':17},'/unused')
        with patch.object(broker,'api',side_effect=[broker.GitHubError(404),broker.GitHubError(403)]):
            with self.assertRaises(broker.GitHubError):broker.execute({'operation':'issue','issue':17},'/unused')

    def test_closed_issue_still_exists(self):
        with patch.object(broker,'api',return_value={'number':17,'state':'closed'}):
            self.assertEqual({'exists':True},broker.execute({'operation':'issue','issue':17},'/unused'))

    def test_comment_absence_has_a_distinct_safe_error(self):
        for status in (404,410):
            with self.subTest(status=status),patch.object(broker,'api',side_effect=broker.GitHubError(status)):
                with self.assertRaises(broker.IssueMissing):broker.execute({'operation':'create_comment','issue':17,'body':'Synthetic'},'/unused')
        with patch.object(broker,'api',side_effect=broker.GitHubError(500)):
            with self.assertRaises(broker.GitHubError):broker.execute({'operation':'create_comment','issue':17,'body':'Synthetic'},'/unused')

    def test_missing_issue_error_survives_private_socket_boundary(self):
        from io import BytesIO
        with patch.object(broker.socket,'socket') as socket:
            socket.return_value.__enter__.return_value.makefile.return_value=BytesIO(b'{"ok":false,"error":"issue_missing"}\n')
            with self.assertRaises(broker.IssueMissing):broker.call('/unused','create_comment',issue=17,body='Synthetic')


if __name__=='__main__':unittest.main()
