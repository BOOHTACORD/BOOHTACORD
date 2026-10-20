"""APT transactions must not restart an in-flight one-job agent or its Docker."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from . import worker


class GuestUpdateTests(unittest.TestCase):
    def test_needrestart_excludes_only_the_two_job_critical_services(self):
        policy = Path(__file__).with_name('needrestart.conf')
        self.assertTrue(policy.is_file(), 'Guest update policy must exist')
        script = r'''our %nrconf; do $ARGV[0] or die "invalid guest policy";
for my $service (@ARGV[1..$#ARGV]) {
    my $restart = 1;
    for my $pattern (keys %{$nrconf{override_rc}}) {
        $restart = $nrconf{override_rc}{$pattern} if $service =~ /$pattern/;
    }
    print "$service=$restart\n";
}'''
        services = ['boohtacord-agent.service', 'docker.service', 'ssh.service',
                    'my-docker.service', 'boohtacord-agent-worker.service']
        result = subprocess.run(['perl', '-e', script, str(policy.resolve()), *services],
                                text=True, capture_output=True, check=True, timeout=10)
        values = dict(line.split('=') for line in result.stdout.splitlines())
        self.assertEqual(['0', '0', '1', '1', '1'], [values[s] for s in services])

    def test_guest_restart_exclusion_is_installed_before_registration_and_execution(self):
        calls = []
        def command(args, **options):
            calls.append(args)
            if args[:4] == ['gh', 'api', '--method', 'POST']:
                return json.dumps({'runner': {'id': 42}, 'encoded_jit_config': 'synthetic-jit'})
            return ''
        with tempfile.TemporaryDirectory() as temporary, patch.object(worker, 'RUNTIME', Path(temporary)), \
                patch.object(worker, 'command', command), patch.object(worker, 'verify_base'), \
                patch.object(worker, 'wait_for_boot'), patch.object(worker, 'monitor_agent', return_value=False), \
                patch.object(worker, 'capture_health'):
            worker.cycle('1')
        config = next(c for c in calls if c[:3] == ['lxc', 'file', 'push']
                      and c[3].endswith('/needrestart.conf'))
        self.assertEqual('boohtacord-ci-1/etc/needrestart/conf.d/boohtacord-ci.conf', config[4])
        self.assertEqual(['--uid', '0', '--gid', '0', '--mode', '0644'], config[5:])
        registration = next(c for c in calls if c[:4] == ['gh', 'api', '--method', 'POST'])
        self.assertLess(calls.index(config), calls.index(registration))
        self.assertFalse(any('boohtacord-ci-base/' in part for c in calls for part in c))
