"""Bounded GET-only metadata client; never downloads Actions logs or artifacts."""
import json
import os
import re
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

ROOT = 'https://api.github.com/repos/BOOHTACORD/BOOHTACORD'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Metadata endpoint unexpectedly redirected')


class Api:
    def __init__(self, token=None, max_requests=1000):
        self.token = token if token is not None else os.environ.get('GITHUB_TOKEN')
        self.max_requests, self.requests = max_requests, 0
        self.remaining = None
        self.opener = build_opener(NoRedirect())

    def get(self, path):
        if not re.fullmatch(r'/actions/[A-Za-z0-9_./?=&%-]+', path) or '..' in path:
            raise ValueError('Only fixed repository Actions metadata paths are allowed')
        if self.requests >= self.max_requests:
            raise RuntimeError('Metadata request budget exhausted; collection is incomplete')
        self.requests += 1
        headers = {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
                   'User-Agent': 'boohtacord-ci-baseline'}
        if self.token:
            headers['Authorization'] = 'Bearer ' + self.token
        try:
            with self.opener.open(Request(ROOT + path, headers=headers), timeout=60) as response:
                self.remaining = response.headers.get('X-RateLimit-Remaining')
                return json.load(response)
        except HTTPError as error:
            raise RuntimeError('Metadata HTTP ' + str(error.code) + '; no partial baseline accepted') from None
        except (URLError, TimeoutError, ValueError):
            raise RuntimeError('Metadata transport/JSON failure; no partial baseline accepted') from None

    def pages(self, path, key):
        rows = []
        for page in range(1, 21):
            data = self.get(path + ('&' if '?' in path else '?') + f'per_page=100&page={page}')
            batch = data[key]
            if not isinstance(batch, list) or not isinstance(data.get('total_count'), int):
                raise ValueError('Metadata response lacks a complete collection count')
            rows.extend(batch)
            if len(rows) == data['total_count']:
                return rows
            if not batch or len(rows) > data['total_count']:
                break
        raise RuntimeError('Metadata pagination incomplete; no partial baseline accepted')
