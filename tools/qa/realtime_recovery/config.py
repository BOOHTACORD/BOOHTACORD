"""Dedicated loopback ports, separate from the shared 4810 QA fixture."""
ORIGIN = 'https://localhost:4910'
PORTS = (4910, 4920, 4980, 4981, 4982)


def sfu(owner):
    return f'''port: 4980
bind_addresses: ["0.0.0.0"]
redis:
  address: {owner}-redis:6379
rtc:
  tcp_port: 4981
  udp_port: 4982
  use_external_ip: false
  enable_loopback_candidate: true
  interfaces:
    includes: ["eth0"]
keys:
  qa-only: qa-local-only-secret-12345
webhook:
  api_key: qa-only
  urls: ["http://{owner}-api:8080/internal/livekit/roster"]
'''


def proxy(owner, root):
    return f'''{{
 admin off
 auto_https disable_redirects
}}
{ORIGIN} {{
 bind 0.0.0.0
 tls internal
 handle /qa-sfu* {{
  uri strip_prefix /qa-sfu
  reverse_proxy {owner}-sfu:4980
 }}
 handle /api/* {{
  reverse_proxy {owner}-api:8080
 }}
 handle {{
  root * "{root}/clients/web/dist"
  try_files {{path}} /index.html
  file_server
 }}
}}
'''
