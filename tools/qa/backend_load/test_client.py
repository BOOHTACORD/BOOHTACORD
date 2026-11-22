import http.server
import threading
import unittest
from unittest.mock import Mock

from .client import ApiClient


class RedirectIsolationTests(unittest.TestCase):
    def test_read_cycle_uses_current_search_api_and_encodes_query(self):
        client = ApiClient('http://127.0.0.1:4820', {}, 2)
        client.request = Mock(return_value=('fixture', 200, 1))
        client.read_cycle('11111111-1111-4111-8111-111111111111', 'space & вопрос')
        self.assertEqual(client.request.call_args_list[2].args, (
            'search', '/search/messages?channel_id=11111111-1111-4111-8111-111111111111'
            '&query=space%20%26%20%D0%B2%D0%BE%D0%BF%D1%80%D0%BE%D1%81&limit=20'))

    def test_redirects_never_escape_the_confirmed_origin(self):
        received = []

        class Destination(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                received.append(self.path)
                self.send_response(200)
                self.end_headers()

            def log_message(self, *args):
                pass

        destination = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Destination)

        class Origin(Destination):
            def do_GET(self):
                if self.path.endswith('/ok'):
                    self.send_response(200)
                    self.end_headers()
                    return
                self.send_response(int(self.path.rsplit('/', 1)[-1]))
                self.send_header('Location', f'http://127.0.0.1:{destination.server_port}/target')
                self.end_headers()

            do_POST = do_GET

        origin = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Origin)
        servers = [origin, destination]
        threads = [threading.Thread(target=server.serve_forever) for server in servers]
        for thread in threads:
            thread.start()
        try:
            client = ApiClient(f'http://127.0.0.1:{origin.server_port}', {}, 2)
            self.assertEqual(client.request('topology', '/ok')[1], 200)
            for body in (None, {'login': 'synthetic', 'password': 'fixture-only'}):
                for status in (301, 302, 303, 307, 308):
                    with self.subTest(status=status, method='POST' if body else 'GET'):
                        result = client.request('topology', f'/{status}', body)
                        self.assertEqual(result[1], status)
                        self.assertEqual(received, [])
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            for thread in threads:
                thread.join(timeout=2)


if __name__ == '__main__':
    unittest.main()
