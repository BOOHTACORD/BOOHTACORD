"""Validated non-secret inputs for an owner-controlled Collector SSH link."""
import base64
import ipaddress
import re
from dataclasses import dataclass

PRIVATE_V4 = tuple(ipaddress.IPv4Network(value) for value in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))


def private_bridge(value):
    if not isinstance(value, str):
        raise ValueError('expected literal IPv4 string')
    address = ipaddress.IPv4Address(value)
    if not any(address in network for network in PRIVATE_V4):
        raise ValueError('bridge bind must be a literal RFC1918 IPv4 address')
    return str(address)


def unicast(value):
    if not isinstance(value, str):
        raise ValueError('expected literal IPv4 string')
    address = ipaddress.IPv4Address(value)
    if address.is_unspecified or address.is_multicast or address.is_loopback or address.is_link_local or address.is_reserved or address in ipaddress.IPv4Network('0.0.0.0/8'):
        raise ValueError('expected a fixed unicast IPv4 address')
    return str(address)


def public_key(value):
    # Reject options, multiple keys and private material. Comments are not used.
    if '\n' in value or '\r' in value:
        raise ValueError('expected exactly one ED25519 public key')
    parts = value.strip().split()
    if len(parts) < 2 or parts[0] != 'ssh-ed25519':
        raise ValueError('expected ED25519 public key, never private material')
    try:
        wire = base64.b64decode(parts[1], validate=True)
    except (ValueError, TypeError) as error:
        raise ValueError('invalid ED25519 public key') from error
    prefix = (11).to_bytes(4, 'big') + b'ssh-ed25519' + (32).to_bytes(4, 'big')
    if len(wire) != len(prefix) + 32 or not wire.startswith(prefix):
        raise ValueError('invalid ED25519 wire public key')
    return parts[0] + ' ' + parts[1]


@dataclass(frozen=True)
class Link:
    api_source_ip: str
    bridge_ip: str
    bridge_interface: str
    monitor_ip: str
    monitor_host_key: str
    monitor_user: str = 'boohtacord-otel'
    monitor_ssh_port: int = 22

    def checked(self):
        unicast(self.api_source_ip)
        private_bridge(self.bridge_ip)
        unicast(self.monitor_ip)
        public_key(self.monitor_host_key)
        if not re.fullmatch(r'(br-[a-f0-9]{12}|docker0)', self.bridge_interface):
            raise ValueError('expected the inspected Docker bridge interface')
        if not re.fullmatch(r'boohtacord-otel(?:-[a-z0-9]{1,12})?', self.monitor_user):
            raise ValueError('use a dedicated telemetry account, never an operator/root account')
        if not isinstance(self.monitor_ssh_port, int) or isinstance(self.monitor_ssh_port, bool) or not 1 <= self.monitor_ssh_port <= 65535:
            raise ValueError('invalid monitor SSH port')
        return self
