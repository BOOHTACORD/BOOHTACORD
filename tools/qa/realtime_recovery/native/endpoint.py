"""Accept local Linux daemons only; never contact a remote test environment."""
import re


def validate_endpoint(endpoint, system):
    pipe = endpoint == 'npipe:////./pipe/dockerDesktopLinuxEngine'
    unix = bool(re.fullmatch(r'unix:///[^?#\r\n]+', endpoint))
    if system != 'linux' or not (pipe or unix):
        raise ValueError('Native R1 requires a local Linux Docker daemon')
