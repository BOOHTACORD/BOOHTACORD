import subprocess
from fnmatch import fnmatch
from urllib.parse import urlsplit


def local_api(value):
    url = urlsplit(value)
    if (url.scheme != 'https' or url.hostname not in {'localhost', '10.0.2.2'}
            or url.port != 4810 or url.path != '/api/v1' or url.username
            or url.password or url.query or url.fragment):
        raise ValueError('QA requires the owned HTTPS API on port 4810')
    return value


def covered_features(paths, catalog):
    return {name for name, item in catalog.items()
            if any(fnmatch(path, pattern) for path in paths for pattern in item['paths'])}


def validate_selection(paths, catalog, selected):
    missing = covered_features(paths, catalog) - selected
    unknown = [path for path in paths if path.startswith(('clients/web/src/', 'clients/flutter/lib/'))
               and not covered_features([path], catalog)]
    if missing or unknown:
        raise ValueError('Uncovered changes: features=' + ','.join(sorted(missing))
                         + '; paths=' + ','.join(unknown))


def changed_paths(root, base):
    tracked=subprocess.check_output(['git','diff','--name-only',base],cwd=root,text=True).splitlines()
    new=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
    return sorted(set(tracked+new))
