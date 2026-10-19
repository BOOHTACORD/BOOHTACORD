"""GET-only metadata retries; assertions, auth, missing evidence and bad JSON never retry."""
import json
import re
import time
from urllib.error import HTTPError,URLError
from urllib.request import Request,build_opener
from tools.ci.baseline.api import NoRedirect,ROOT
from .policy import load


def get(path,token,opener=None):
    if not token or not re.fullmatch(r'/actions/[A-Za-z0-9_./?=&%-]+',path) or '..' in path:
        raise ValueError('Fixed repository metadata GET required')
    reader=opener or build_opener(NoRedirect())
    policy=load()
    for attempt in range(policy['metadata_get_max_attempts']):
        try:
            request=Request(ROOT+path,headers={'Accept':'application/vnd.github+json','Authorization':'Bearer '+token,
                                             'X-GitHub-Api-Version':'2022-11-28','User-Agent':'boohtacord-ci-triage'},method='GET')
            with reader.open(request,timeout=15) as response:raw=response.read(2_000_001)
        except (HTTPError,TimeoutError,URLError) as error:
            transient=(isinstance(error,HTTPError) and error.code in policy['retry_http_statuses']
                       or isinstance(error,TimeoutError)
                       or isinstance(error,URLError) and isinstance(error.reason,(TimeoutError,ConnectionResetError)))
            if not transient or attempt==1:raise RuntimeError('Actions metadata unavailable; evidence incomplete') from None
            time.sleep(.1);continue
        if len(raw)>2_000_000:raise ValueError('Actions metadata exceeds bound')
        return json.loads(raw)
    raise RuntimeError('Metadata request budget exceeded')
