import ipaddress
from urllib.parse import urlsplit


CONFIRMATION = 'ISOLATED_TEST_DEPLOYMENT'


def validate_run(target, vus, account_count, confirmation):
    if confirmation != CONFIRMATION:
        raise ValueError('explicit isolated-test confirmation is required')
    if not 1 <= vus <= 100 or account_count < vus or account_count > 100:
        raise ValueError('use 1..100 synthetic accounts and at least one per VU')
    url = urlsplit(target)
    if url.scheme not in ('http', 'https') or not url.hostname or url.username or url.password:
        raise ValueError('target must be an origin URL without credentials')
    if url.path not in ('', '/') or url.query or url.fragment:
        raise ValueError('target must contain only scheme, host and optional port')
    host = url.hostname.lower().rstrip('.')
    if host in ('localhost',) or host.endswith('.test'):
        return
    try:
        address = ipaddress.ip_address(host)
    except ValueError as error:
        raise ValueError('DNS targets must use localhost or the reserved .test suffix') from error
    private_networks = (ipaddress.ip_network('10.0.0.0/8'),
                        ipaddress.ip_network('172.16.0.0/12'),
                        ipaddress.ip_network('192.168.0.0/16'),
                        ipaddress.ip_network('fc00::/7'))
    if not (address.is_loopback or any(address in network for network in private_networks)):
        raise ValueError('target must be loopback or a private isolated address')
