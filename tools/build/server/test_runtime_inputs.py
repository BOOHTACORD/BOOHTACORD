"""Runtime bundle selection tests for release-time rollout dependencies."""
import unittest
from pathlib import PurePosixPath

from tools.build.server.inputs import RUNTIME_PATHS
from tools.release.delivery.transfer import DRIVER_PATHS


class RuntimeInputsTests(unittest.TestCase):
    def test_runtime_bundle_includes_livekit_private_path_preflight(self):
        self.assertIn("tools/release/rollout/livekit_private_path.py", RUNTIME_PATHS)

    def test_public_catalog_helper_is_in_runtime_and_current_controller_archives(self):
        helper = PurePosixPath('tools/release/install/public_catalog/prepare.py')
        for paths in (RUNTIME_PATHS, DRIVER_PATHS):
            with self.subTest(paths=paths):
                self.assertTrue(any(helper.is_relative_to(PurePosixPath(path)) for path in paths))


if __name__ == "__main__":
    unittest.main()
