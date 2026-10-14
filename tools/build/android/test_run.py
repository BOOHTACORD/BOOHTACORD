"""Release command regression: Flutter must regenerate its release plugin list."""
import contextlib
import json
import unittest
from unittest.mock import patch

from . import run as builder


class BuildCommandTests(unittest.TestCase):
    def test_release_regenerates_plugins_after_locked_dependency_resolution(self):
        commands = []

        def capture(*args, **kwargs):
            commands.append(args)
            if args[:3] == ('flutter', 'build', 'apk'):
                raise InterruptedError('stop before invoking the native build')

        with patch('sys.argv', ['android-build']), \
             patch.dict('os.environ', {'GITHUB_REF_NAME': 'android-v1.0.42'}), \
             patch.object(builder, 'output', return_value=json.dumps({'frameworkVersion': '3.47.7'})), \
             patch.object(builder, 'require_version'), \
             patch.object(builder, 'version', return_value='1.0.42+77'), \
             patch.object(builder, 'provision', return_value=contextlib.nullcontext()), \
             patch.object(builder, 'run', side_effect=capture):
            with self.assertRaises(InterruptedError):
                builder.main()

        self.assertIn(('flutter', 'pub', 'get', '--enforce-lockfile'), commands)
        build = commands[-1]
        self.assertIn('--release', build)
        self.assertIn('--split-per-abi', build)
        self.assertNotIn('--no-pub', build)


if __name__ == '__main__':
    unittest.main()
