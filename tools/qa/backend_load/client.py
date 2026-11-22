import http.cookiejar
import json
import time
import urllib.error
import urllib.parse
import urllib.request


class RejectRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        return None


class ApiClient:
    def __init__(self, origin, account, timeout):
        self.base = origin.rstrip('/') + '/api/v1'
        self.origin = origin.rstrip('/')
        self.account = account
        self.timeout = timeout
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
            RejectRedirects())

    def request(self, operation, path, body=None):
        headers = {'Accept': 'application/json', 'Origin': self.origin}
        data = None
        method = 'GET'
        if body is not None:
            method = 'POST'
            headers['Content-Type'] = 'application/json'
            data = json.dumps(body).encode('utf-8')
        request = urllib.request.Request(self.base + path, data=data, headers=headers,
                                         method=method)
        started = time.perf_counter()
        status = 0
        try:
            with self.opener.open(request, timeout=self.timeout) as response:
                status = response.status
                response.read(2_000_001)
        except urllib.error.HTTPError as error:
            status = error.code
            error.read(2_000_001)
        except (TimeoutError, urllib.error.URLError, OSError):
            status = 0
        return operation, status, (time.perf_counter() - started) * 1000

    def login(self):
        result = self.request('login', '/auth/login', self.account)
        if result[1] != 204:
            raise RuntimeError('synthetic account login failed')
        return result

    def read_cycle(self, channel_id, query):
        encoded_query = urllib.parse.quote(query, safe='')
        return [
            self.request('topology', '/channels'),
            self.request('history', f'/channels/{channel_id}/messages?limit=50'),
            self.request('search', f'/search/messages?channel_id={channel_id}&query={encoded_query}&limit=20'),
        ]
