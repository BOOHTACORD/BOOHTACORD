"""Read-only systemd preflight: refuse an absent, changed or public bind address.

This file is also installed standalone on the API host; use stdlib only.
"""
import argparse
import ipaddress
import json
import re
import shutil
import subprocess


def verify(interface, address, interfaces):
    ip = ipaddress.IPv4Address(address)
    private = ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
    if not any(ip in ipaddress.IPv4Network(network) for network in private):
        raise ValueError('telemetry listener must bind RFC1918 Docker bridge only')
    if not re.fullmatch(r'(br-[a-f0-9]{12}|docker0)', interface):
        raise ValueError('unexpected Docker bridge interface')
    for item in interfaces:
        if item.get('ifname') != interface or 'UP' not in item.get('flags', []):
            continue
        if any(info.get('family') == 'inet' and info.get('local') == address and info.get('scope') == 'global'
               for info in item.get('addr_info', [])):
            return
    raise ValueError('expected private Docker bridge/address is absent; refusing alternate listener')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--interface', required=True)
    parser.add_argument('--address', required=True)
    args = parser.parse_args()
    # Avoid inherited PATH lookup. No commands alter networking or credentials.
    binary = shutil.which('ip', path='/usr/sbin:/usr/bin:/sbin:/bin')
    if not binary:
        raise SystemExit('iproute2 is required for read-only binding verification')
    result = subprocess.run([binary, '-json', 'address', 'show', 'dev', args.interface],
                            check=True, capture_output=True, text=True, timeout=5)
    verify(args.interface, args.address, json.loads(result.stdout))


if __name__ == '__main__':
    main()
