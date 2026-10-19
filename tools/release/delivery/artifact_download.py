"""Bounded artifact transport; never forward API credentials to a signed blob URL."""
import os
from pathlib import Path
import re
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from .artifact_zip import MAX_ARCHIVE
from .consumer import REPOSITORY


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def checked_url(url):
    value = urlsplit(url)
    if (value.scheme != 'https' or not value.hostname or value.username or value.password
            or value.port not in (None, 443) or value.fragment
            or not any(value.hostname.endswith(suffix) for suffix in ('.blob.core.windows.net', '.actions.githubusercontent.com'))):
        raise ValueError('Unexpected artifact storage endpoint')
    return url


def location(artifact_id, token, *, opener=None):
    if (type(artifact_id) is not int or artifact_id <= 0 or not isinstance(token, str)
            or not token or '\r' in token or '\n' in token):
        raise ValueError('Invalid artifact request authority')
    opener = opener or build_opener(NoRedirect())
    request = Request(f'https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{artifact_id}/zip',
                      headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json'})
    try:
        try:
            with opener.open(request, timeout=30): pass
        except HTTPError as error:
            try:
                if error.code != 302: raise ValueError
                return checked_url(error.headers.get('Location', ''))
            finally: error.close()
        raise ValueError
    except Exception:
        raise ValueError('Cannot obtain trusted artifact storage location') from None


def receive(url, destination, size, *, opener=None):
    destination = Path(destination); created = False
    try:
        checked_url(url)
        if (type(size) is not int or not 0 < size <= MAX_ARCHIVE or not destination.is_absolute()
                or destination.parent.resolve() != destination.parent): raise ValueError
        opener = opener or build_opener(NoRedirect())
        started = time.monotonic()
        with opener.open(Request(url, headers={'Accept': 'application/octet-stream'}), timeout=30) as response:
            length = response.headers.get('Content-Length')
            if (response.status != 200 or response.headers.get('Content-Encoding', 'identity') != 'identity'
                    or (length is not None and (not re.fullmatch('[0-9]+', length) or int(length) != size))): raise ValueError
            descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            created = True; count = 0
            with os.fdopen(descriptor, 'wb') as stream:
                while block := response.read(min(1024*1024, size-count+1)):
                    count += len(block)
                    if count > size or time.monotonic()-started > 300: raise ValueError
                    stream.write(block)
                if count != size or time.monotonic()-started > 300: raise ValueError
    except Exception:
        if created: destination.unlink(missing_ok=True)
        raise ValueError('Cannot download the complete bounded artifact') from None
