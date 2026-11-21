import unittest
from .endpoint import validate_endpoint


class EndpointTest(unittest.TestCase):
    def test_accepts_only_local_linux_daemons(self):
        for value in ('unix:///var/run/docker.sock',
                      'npipe:////./pipe/dockerDesktopLinuxEngine'):
            validate_endpoint(value, 'linux')

    def test_rejects_remote_and_wrong_daemon(self):
        for value, system in [('tcp://127.0.0.1:2375', 'linux'),
                              ('ssh://remote', 'linux'),
                              ('npipe:////remote/pipe/docker_engine', 'linux'),
                              ('npipe:////./pipe/other', 'linux'),
                              ('unix:///var/run/docker.sock', 'windows')]:
            with self.assertRaises(ValueError):
                validate_endpoint(value, system)
