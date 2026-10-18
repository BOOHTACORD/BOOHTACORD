"""Change only owned upstreams/static serving in the production Caddy route."""
import re


def configuration(source, owner, site):
    if not re.fullmatch(r'qa-client-[a-z0-9]+', owner) or not re.fullmatch(r'/[a-zA-Z0-9_/.-]+', site):
        raise ValueError('Invalid owned proxy destination')
    required=('log_skip @rtc', 'forward_auth api:8080 {', 'uri /internal/media-admission',
              'header_up X-Forwarded-Uri {uri}', 'reverse_proxy livekit:7880', 'reverse_proxy web:80')
    if any(s not in source for s in required):
        raise ValueError('Production signal authorization route is required')
    return (source.replace('{$PUBLIC_HOST:localhost}', 'https://localhost:4830')
            .replace('api:8080', owner+'-api:8080')
            .replace('livekit:7880', owner+'-sfu:4880')
            .replace('reverse_proxy web:80', f'root * {site}\n\t\tfile_server'))
