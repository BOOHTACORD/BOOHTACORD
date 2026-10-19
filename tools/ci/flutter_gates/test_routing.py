"""Both native children remain mandatory exactly when the shared selector requires Flutter."""
import unittest
from tools.ci.select_changes.selection import classify


class RoutingTests(unittest.TestCase):
    def test_android_native_shared_contract_and_toolchain_changes_require_flutter(self):
        for name in ('clients/flutter/lib/src/app_state.dart', 'clients/flutter/android/app/build.gradle.kts',
                     'clients/flutter/packages/livekit_client/lib/src/core/room.dart',
                     'clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream/src/denoise.c',
                     'contracts/mobile-client-contract.md', 'tools/toolchains.json',
                     'tools/ci/flutter_setup/locks/livekit_client.lock', 'tools/build/android/run.py',
                     '.github/workflows/ci-flutter.yaml', 'unknown/ownership'):
            with self.subTest(path=name): self.assertIn('flutter', classify([name])['gates'])

    def test_unrelated_web_backend_and_docs_do_not_start_native_packaging(self):
        for paths in (['backend/internal/auth/service.go'], ['clients/web/src/main.ts'],
                      ['docs/ci/flutter-gates.md'], ['backend/main.go', 'clients/web/src/main.ts'], []):
            with self.subTest(paths=paths): self.assertNotIn('flutter', classify(paths)['gates'])
        self.assertIn('flutter', classify(None)['gates'])
