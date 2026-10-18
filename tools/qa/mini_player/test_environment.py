import os
from pathlib import Path
import unittest
from . import environment


class NativeEnvironment(unittest.TestCase):
    def test_preserves_caller_docker_sdk_jdk_and_toolchain_order(self):
        caller = {'PATH': os.pathsep.join(['/pinned/flutter/bin', '/opt/homebrew/bin', '/usr/bin']),
                  'DOCKER_CONTEXT': 'owned-task', 'DOCKER_CONFIG': '/owned/docker',
                  'ANDROID_HOME': '/owned/sdk', 'ANDROID_SDK_ROOT': '/owned/sdk',
                  'JAVA_HOME': '/owned/java'}
        before = dict(caller)
        result = environment.native_environment(caller)
        self.assertEqual(caller, before)
        for name in ('DOCKER_CONTEXT', 'DOCKER_CONFIG', 'ANDROID_HOME',
                     'ANDROID_SDK_ROOT', 'JAVA_HOME'):
            self.assertEqual(result[name], caller[name])
        paths = result['PATH'].split(os.pathsep)
        self.assertEqual(paths[0], str(Path('/owned/sdk') / 'platform-tools'))
        self.assertLess(paths.index('/pinned/flutter/bin'), paths.index('/opt/homebrew/bin'))

    def test_explicit_flutter_root_wins_over_host_package_manager(self):
        result = environment.native_environment({
            'FLUTTER_ROOT': '/pinned/flutter', 'PATH': os.pathsep.join(['/opt/homebrew/bin', '/usr/bin']),
        })
        paths = result['PATH'].split(os.pathsep)
        self.assertLess(paths.index(str(Path('/pinned/flutter') / 'bin')), paths.index('/opt/homebrew/bin'))

    def test_only_missing_values_receive_local_host_defaults(self):
        result = environment.native_environment({'PATH': '/usr/bin'})
        self.assertEqual(result['DOCKER_CONTEXT'], 'colima-boohtacord-qa')
        self.assertEqual(result['ANDROID_HOME'], result['ANDROID_SDK_ROOT'])
        self.assertTrue(result['PATH'].endswith(os.pathsep + '/usr/bin'))
        self.assertIn('openjdk@17', result['JAVA_HOME'])
