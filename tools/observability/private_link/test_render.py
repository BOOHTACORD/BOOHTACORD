"""Private owner diagnostics must not become public/local unrestricted SSH."""
import base64
import dataclasses
import json
import os
import tempfile
import unittest
from pathlib import Path

from .render import Link, render, write_bundle


def key(seed=1):
    kind = b'ssh-ed25519'
    wire = len(kind).to_bytes(4, 'big') + kind + (32).to_bytes(4, 'big') + bytes([seed]) * 32
    return 'ssh-ed25519 ' + base64.b64encode(wire).decode()


def configuration():
    return Link(api_source_ip='198.51.100.20', bridge_ip='172.19.0.1',
                bridge_interface='br-0123456789ab', monitor_ip='167.233.56.32',
                monitor_host_key=key(2))


class RenderTests(unittest.TestCase):
    def test_private_bridge_render_is_pinned_and_has_no_public_listener(self):
        files = render(configuration(), public_key=key())
        config = files['ssh_config']
        self.assertIn('LocalForward 172.19.0.1:14318 127.0.0.1:4318', config)
        for option in ('StrictHostKeyChecking yes', 'BatchMode yes', 'IdentityAgent none',
                       'ExitOnForwardFailure yes', 'ServerAliveInterval 15', 'ServerAliveCountMax 3',
                       'ForwardAgent no', 'ProxyCommand none', 'ControlMaster no'):
            self.assertIn(option, config)
        unit = files['boohtacord-telemetry-private-link.service']
        self.assertIn('DynamicUser=yes', unit)
        self.assertIn('RestrictAddressFamilies=AF_INET AF_UNIX AF_NETLINK', unit)
        self.assertIn('Restart=always', unit)
        self.assertIn('CapabilityBoundingSet=\n', unit)
        self.assertIn('LoadCredential=id_ed25519:', unit)
        self.assertIn('-i %d/id_ed25519', unit)
        self.assertIn('-o UserKnownHostsFile=%d/known_hosts', unit)
        self.assertIn('check_binding.py --interface br-0123456789ab --address 172.19.0.1', unit)
        self.assertNotIn('0.0.0.0', unit + config)
        self.assertNotIn('accept-new', unit + config)
        self.assertNotIn('BEGIN OPENSSH PRIVATE KEY', '\n'.join(files.values()))
        self.assertEqual('167.233.56.32 ' + key(2) + '\n', files['known_hosts'])
        manifest = json.loads(files['plan.json'])
        self.assertEqual('http://172.19.0.1:14318', manifest['api_otlp_endpoint'])
        self.assertEqual('unchanged', manifest['central_export_mode'])

    def test_all_public_wildcard_loopback_and_injection_binds_fail(self):
        for address in ('0.0.0.0', '167.233.56.32', '127.0.0.1', '::', '::1',
                        'collector.example.org', '172.19.0.1\nLocalForward 0.0.0.0:99 host:99'):
            with self.subTest(address=address), self.assertRaises(ValueError):
                render(dataclasses.replace(configuration(), bridge_ip=address))

    def test_only_dedicated_monitor_user_and_fixed_ingest_destination(self):
        files = render(configuration(), public_key=key())
        policy = files['monitor-sshd.conf']
        for directive in ('Match User boohtacord-otel', 'AllowTcpForwarding local',
                          'AllowStreamLocalForwarding no', 'PermitListen none',
                          'PermitOpen 127.0.0.1:4318', 'MaxSessions 0', 'ForceCommand /usr/bin/false',
                          'PermitTTY no', 'AllowAgentForwarding no', 'PermitUserRC no'):
            self.assertIn(directive, policy)
        entry = files['monitor-authorized-key']
        self.assertIn('restrict,port-forwarding,', entry)
        self.assertIn('from="198.51.100.20"', entry)
        self.assertIn('permitopen="127.0.0.1:4318"', entry)
        self.assertNotIn('permitlisten="none"', entry)  # Invalid authorized_keys syntax.
        self.assertNotIn('root@', files['ssh_config'])
        for user in ('root', 'shaneque', 'user\nForceCommand /bin/sh'):
            with self.subTest(user=user), self.assertRaises(ValueError):
                render(dataclasses.replace(configuration(), monitor_user=user))

    def test_render_without_key_is_explicit_uninstallable_template(self):
        files = render(configuration())
        self.assertNotIn('monitor-authorized-key', files)
        self.assertIn('API_GENERATED_ED25519_PUBLIC_KEY', files['monitor-authorized-key.template'])
        self.assertEqual('pending_public_key', json.loads(files['plan.json'])['state'])

    def test_key_metadata_and_configuration_injections_are_rejected(self):
        for public in ('ssh-rsa abc', key() + '\n' + key(), 'restrict ' + key(),
                       'ssh-ed25519 AAAA', '-----BEGIN OPENSSH PRIVATE KEY-----'):
            with self.subTest(public=public), self.assertRaises(ValueError):
                render(configuration(), public_key=public)
        for field, value in (('bridge_interface', 'eth0'), ('bridge_interface', 'br-123;id'),
                             ('monitor_ip', 'host.example.org'), ('api_source_ip', '*'),
                             ('monitor_host_key', 'ssh-ed25519 AAAA')):
            with self.subTest(field=field), self.assertRaises(ValueError):
                render(dataclasses.replace(configuration(), **{field: value}))

    def test_bundle_is_new_directory_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as folder:
            dest = Path(folder) / 'bundle'
            write_bundle(dest, render(configuration()))
            with self.assertRaises(FileExistsError):
                write_bundle(dest, render(configuration()))

    @unittest.skipUnless(os.name == 'posix', 'POSIX modes apply to the Ubuntu runtime; Windows requires ACL review')
    def test_bundle_posix_permissions(self):
        with tempfile.TemporaryDirectory() as folder:
            dest = Path(folder) / 'bundle'
            write_bundle(dest, render(configuration()))
            self.assertEqual(0o700, dest.stat().st_mode & 0o777)
            self.assertEqual(0o600, (dest / 'ssh_config').stat().st_mode & 0o777)

    def test_real_openssh_parser_accepts_client_configuration_without_connecting(self):
        import shutil
        import subprocess
        ssh = shutil.which('ssh')
        if not ssh:
            self.skipTest('OpenSSH client unavailable; no runtime connection attempted')
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / 'ssh_config'
            config.write_text(render(configuration())['ssh_config'])
            parsed = subprocess.run([ssh, '-G', '-F', str(config), '-i', os.devnull,
                                     '-o', 'UserKnownHostsFile=' + os.devnull, '-NTn',
                                     'boohtacord-otel-monitor'], capture_output=True, text=True,
                                    check=True, timeout=5)
            settings = dict(line.split(' ', 1) for line in parsed.stdout.splitlines() if ' ' in line)
            for option in ('stricthostkeychecking', 'identitiesonly', 'exitonforwardfailure'):
                self.assertIn(settings[option], ('yes', 'true'))
            self.assertEqual('15', settings['serveraliveinterval'])
            self.assertEqual('3', settings['serveralivecountmax'])
            self.assertEqual('boohtacord-otel', settings['user'])
            self.assertEqual('inet', settings['addressfamily'])
            self.assertRegex(parsed.stdout, r'localforward \[?172\.19\.0\.1\]?:14318 \[?127\.0\.0\.1\]?:4318')
