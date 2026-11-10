"""Read native-run metadata from GitHub without forwarding credentials."""
import re
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from .producer import PLATFORMS, select_native_artifact
from .publication import parse_record

API = 'https://api.github.com/repos/BOOHTACORD/BOOHTACORD'
PATH = re.compile(r'/actions/runs/[1-9][0-9]*(?:/artifacts)?\Z')


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def urlopen_no_redirect(request):
    return build_opener(NoRedirect()).open(request, timeout=20)


def read_api(path, token):
    if not isinstance(path, str) or not PATH.fullmatch(path):
        raise ValueError('invalid GitHub API path')
    if token is not None and (not isinstance(token, str) or
                              not re.fullmatch(r'[A-Za-z0-9_-]{1,512}', token)):
        raise ValueError('invalid GitHub API credential format')
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'boohtacord-product-map',
               'X-GitHub-Api-Version': '2022-11-28'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        with urlopen_no_redirect(Request(API + path, headers=headers)) as response:
            if response.status != 200:
                raise ValueError('GitHub API did not return success')
            return parse_record(response.read(4_000_001))
    except (HTTPError, URLError, OSError) as error:
        raise ValueError('GitHub API metadata request failed') from None


def fetch_candidate(platform, run_id, tag, token=None):
    if (platform not in PLATFORMS or type(run_id) is not int or run_id <= 0 or
            not isinstance(tag, str) or
            not re.fullmatch(re.escape(platform) + r'-v\d+\.\d+\.\d+', tag)):
        raise ValueError('invalid native release identity')
    path = f'/actions/runs/{run_id}'
    return select_native_artifact(read_api(path, token), read_api(path + '/artifacts', token),
                                  platform, run_id, tag)
