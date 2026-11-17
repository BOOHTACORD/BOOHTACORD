"""Local-only disposable service ownership and configuration."""
import os
import socket
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

LABEL = 'boohtacord.qa.owner'


def run(*args, **options):
    return subprocess.run(args, check=True, **options)


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def ports_available(ports):
    for port in ports:
        with socket.socket() as listener:
            # TIME_WAIT from the previous owned run is not an active service.
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(('127.0.0.1', port))


def read_only_directory_mount(source, target):
    directory = Path(source)
    if not directory.is_dir() or not target.startswith('/'):
        raise ValueError('Read-only config mounts require an existing source directory and absolute target')
    return '--mount', f'type=bind,source={directory.resolve()},target={target},readonly'


def local_origin(value):
    url = urlsplit(value)
    if (url.scheme != 'https' or url.hostname != 'localhost' or url.username
            or url.password or url.port != 4810 or url.path or url.query or url.fragment):
        raise ValueError('Only the disposable localhost TLS origin is permitted')
    return value


def local_docker():
    endpoint = os.environ.get('DOCKER_HOST')
    if not endpoint:
        context = output('docker', 'context', 'show')
        endpoint = output('docker', 'context', 'inspect', context,
                          '--format', '{{.Endpoints.docker.Host}}')
    if not endpoint.startswith('unix://'):
        raise ValueError('A local Linux Docker daemon is required')


def remove_owned(name, owner, kind='container'):
    if kind == 'container' or kind == 'image':
        template = '{{index .Config.Labels "'+LABEL+'"}}'
    elif kind == 'network':
        template = '{{index .Labels "'+LABEL+'"}}'
    elif kind == 'volume':
        template = '{{index .Labels "'+LABEL+'"}}'
    else:
        raise ValueError('Refusing to remove an unsupported resource kind')
    target = ('image' if kind == 'image' else kind)
    label = output('docker', target, 'inspect', name, '--format', template)
    if label != owner:
        raise ValueError('Refusing to remove a foreign resource')
    args = ['docker', target, 'rm'] + (['-f'] if kind == 'container' else []) + [name]
    run(*args, stdout=subprocess.DEVNULL)


TEMPO = '''server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
ingester:
  max_block_duration: 1m
compactor:
  compaction:
    block_retention: 1h
storage:
  trace:
    backend: local
    wal:
      path: /tmp/tempo/wal
    local:
      path: /tmp/tempo/blocks
usage_report:
  reporting_enabled: false
'''


def caddy_config(root):
    return '''{
  admin off
  auto_https disable_redirects
}
https://localhost:4810 {
  bind 127.0.0.1
  tls internal
  handle /api/* {
    reverse_proxy 127.0.0.1:4820
  }
  handle {
    root * "'''+str(root / 'clients/web/dist')+'''"
    try_files {path} /index.html
    file_server
  }
}
'''
