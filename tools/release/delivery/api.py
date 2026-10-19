"""Bounded read-only GitHub producer metadata, with no response-body logging."""
import json
import re
from urllib.request import Request, urlopen


class Reader:
    def __init__(self, repository, run_id, token):
        if (not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository)
                or not re.fullmatch(r'[1-9][0-9]{0,19}', run_id)):
            raise ValueError('Invalid producer identity')
        self.root = f'https://api.github.com/repos/{repository}/actions/runs/{run_id}'
        self.token = token

    def read(self, suffix=''):
        request = Request(self.root + ('/' + suffix if suffix else ''), headers={
            'Authorization': 'Bearer ' + self.token, 'Accept': 'application/vnd.github+json'})
        try:
            with urlopen(request, timeout=30) as response:
                body = response.read(2 * 1024 * 1024 + 1)
            if len(body) > 2 * 1024 * 1024:
                raise ValueError('Oversized producer metadata')
            document = json.loads(body)
            if not isinstance(document, dict):
                raise ValueError('Invalid producer metadata')
            return document
        except (OSError, ValueError):
            raise ValueError('Cannot read bounded producer metadata') from None

    def collection(self, kind):
        if kind not in ('jobs', 'artifacts'):
            raise ValueError('Unexpected producer collection')
        rows, expected = [], None
        for page in range(1, 21):
            query = 'filter=latest&' if kind == 'jobs' else ''
            document = self.read(f'{kind}?{query}per_page=100&page={page}')
            count, batch = document.get('total_count'), document.get(kind)
            if (type(count) is not int or not 0 <= count <= 2000
                    or (expected is not None and expected != count)
                    or not isinstance(batch, list) or len(batch) > 100
                    or any(not isinstance(row, dict) for row in batch)):
                raise ValueError('Invalid or changing producer collection')
            expected = count
            rows.extend(batch)
            if len(rows) == count:
                return {'total_count': count, kind: rows}
            if len(rows) > count or not batch:
                break
        raise ValueError('Truncated producer collection')
