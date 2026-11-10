"""Follow a GitHub artifact redirect without sending its token to storage."""
import hashlib
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request

from tools.product_map.release.github_api import API, urlopen_no_redirect, validate_token


def _storage_url(value):
    try:
        url = urlsplit(value)
        host = url.hostname or ''
        allowed = (host.endswith('.blob.core.windows.net') or
                   host.endswith('.actions.githubusercontent.com') or
                   host == 'objects.githubusercontent.com')
        if (url.scheme != 'https' or not allowed or url.port not in (None, 443) or
                url.username is not None or url.password is not None or url.fragment or
                any(ord(c) < 32 for c in value)):
            raise ValueError
    except (TypeError, ValueError):
        raise ValueError('untrusted artifact storage redirect') from None
    return value


def download_artifact(candidate, token):
    validate_token(token)
    identifier, size, digest = (candidate.get('artifact_id'), candidate.get('artifact_size'),
                                candidate.get('artifact_digest'))
    if (candidate.get('status') != 'CANDIDATE_UNVERIFIED' or type(identifier) is not int or
            identifier <= 0 or type(size) is not int or not 0 < size <= 32_000_000 or
            not isinstance(digest, str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', digest)):
        raise ValueError('invalid artifact candidate')
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'boohtacord-product-map'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = Request(f'{API}/actions/artifacts/{identifier}/zip', headers=headers)
    try:
        with urlopen_no_redirect(request):
            raise ValueError('GitHub artifact redirect missing')
    except HTTPError as error:
        if error.code != 302:
            raise ValueError('GitHub artifact request failed') from None
        location = _storage_url(error.headers.get('Location'))
    except (URLError, OSError):
        raise ValueError('GitHub artifact request failed') from None
    try:
        with urlopen_no_redirect(Request(location, headers={'User-Agent': 'boohtacord-product-map'})) as response:
            if response.status != 200:
                raise ValueError('artifact storage request failed')
            data = response.read(size + 1)
    except (HTTPError, URLError, OSError, ValueError):
        raise ValueError('artifact storage request failed') from None
    if len(data) != size or 'sha256:' + hashlib.sha256(data).hexdigest() != digest:
        raise ValueError('artifact size or digest mismatch')
    return data
