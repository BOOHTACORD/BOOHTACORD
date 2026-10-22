"""Render reviewable private-link files; never connect, create keys or install.

Run as a module. All inputs are public topology/key metadata. The API's private
key must be generated and remain on the API host after operator review.
"""
import argparse
import json
from pathlib import Path
from string import Template

from .model import Link, public_key as checked_public_key

HERE = Path(__file__).parent


def render(config, public_key=None):
    config.checked()
    values = dict(vars(config))
    files = {
        'ssh_config': Template((HERE / 'ssh_config.in').read_text()).substitute(values),
        'boohtacord-telemetry-private-link.service': Template((HERE / 'service.in').read_text()).substitute(values),
        'monitor-sshd.conf': Template((HERE / 'monitor_sshd.in').read_text()).substitute(values),
        'check_binding.py': (HERE / 'verify_binding.py').read_text(),
    }
    host = config.monitor_ip if config.monitor_ssh_port == 22 else '[' + config.monitor_ip + ']:' + str(config.monitor_ssh_port)
    files['known_hosts'] = host + ' ' + checked_public_key(config.monitor_host_key) + '\n'
    restriction = ('restrict,port-forwarding,from="' + config.api_source_ip
                   + '",permitopen="127.0.0.1:4318",command="/usr/bin/false" ')
    if public_key is None:
        files['monitor-authorized-key.template'] = restriction + 'API_GENERATED_ED25519_PUBLIC_KEY boohtacord-local-otel\n'
    else:
        files['monitor-authorized-key'] = restriction + checked_public_key(public_key) + ' boohtacord-local-otel\n'
    files['plan.json'] = json.dumps({
        'state': 'ready_for_operator_review' if public_key else 'pending_public_key',
        'api_otlp_endpoint': 'http://' + config.bridge_ip + ':14318',
        'monitor_destination': '127.0.0.1:4318',
        'monitor_user': config.monitor_user,
        'api_source_ip': config.api_source_ip,
        'bridge_interface': config.bridge_interface,
        'central_export_mode': 'unchanged',
        'access': 'dedicated SSH local TCP forwarding to owner Collector only',
        'production_apply': 'not performed by renderer; review, validate and apply separately',
    }, indent=2) + '\n'
    return files


def write_bundle(destination, files):
    destination = Path(destination)
    destination.mkdir(mode=0o700, exist_ok=False)
    for name, content in files.items():
        path = destination / name
        with path.open('x', encoding='utf-8') as handle:
            path.chmod(0o600)
            handle.write(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-source-ip', required=True)
    parser.add_argument('--bridge-ip', required=True)
    parser.add_argument('--bridge-interface', required=True)
    parser.add_argument('--monitor-ip', required=True)
    parser.add_argument('--monitor-user', default='boohtacord-otel')
    parser.add_argument('--monitor-ssh-port', type=int, default=22)
    parser.add_argument('--monitor-host-key-file', type=Path, required=True)
    parser.add_argument('--api-public-key-file', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    # One final newline on public key files is conventional; embedded lines fail.
    host_key = args.monitor_host_key_file.read_text().rstrip('\n')
    key = args.api_public_key_file.read_text().rstrip('\n') if args.api_public_key_file else None
    config = Link(args.api_source_ip, args.bridge_ip, args.bridge_interface, args.monitor_ip,
                  host_key, args.monitor_user, args.monitor_ssh_port)
    write_bundle(args.output, render(config, key))
    print('Private-link bundle rendered for review; no keys created or hosts changed.')


if __name__ == '__main__':
    main()
