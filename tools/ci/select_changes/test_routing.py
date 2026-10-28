import unittest
from .selection import ALL, classify, select


class RoutingTests(unittest.TestCase):
    def test_one_map_drives_required_gates_and_both_release_impacts(self):
        cases = [
            (['docs/ci/readme.md', 'evidence/ci/run.json'], {'contracts'}, False, False),
            (['backend/internal/config/config.go'], {'contracts', 'backend', 'server'}, True, False),
            (['clients/web/src/main.ts'], {'contracts', 'web', 'server'}, True, False),
            (['clients/flutter/lib/main.dart'], {'contracts', 'flutter', 'windows'}, False, True),
            (['tools/build/windows/run.py'], {'contracts', 'flutter', 'windows'}, False, True),
            (['tools/release/desktop_updates/sign.py'], {'contracts', 'flutter', 'windows'}, False, True),
            (['tools/build/web/build.py'], {'contracts', 'web', 'server'}, True, False),
            (['tools/qa/local_features/features.json'],
             {'contracts', 'backend', 'web', 'flutter'}, False, False),
            (['tools/qa/critical_client_acceptance/screen_share_ui.mjs'], {'contracts', 'web'}, False, False),
            (['tools/qa/critical_client_acceptance/select_stream.mjs'], {'contracts', 'web'}, False, False),
            (['tools/qa/critical_client_acceptance/select_stream.test.mjs'], {'contracts', 'web'}, False, False),
            (['tools/ci/select_changes/dependencies.json'], {'contracts'}, False, False),
            (['tools/ci/select_changes/test_routing.py'], {'contracts'}, False, False),
            (['tools/ci/actual_acceptance/plan-v1.json'], {'contracts'}, False, False),
            (['tools/ci/actual_acceptance/test_plan.py'], {'contracts'}, False, False),
            (['evidence/media/livekit-network-config-2026.json'], {'contracts', 'backend', 'web', 'server'}, True, False),
            (['deploy/compose.yaml'], {'contracts', 'backend', 'web', 'server'}, True, False),
            (['tools/release/bundle/signature.py'], set(ALL), True, True),
            (['contracts/api.yaml'], set(ALL), True, True),
            (['tools/audio/model.py'], set(ALL), True, True),
            (['.github/workflows/ci.yaml'], set(ALL), True, True),
            (['new-runtime/unknown.conf'], set(ALL), True, True),
            (None, set(ALL), True, True), ([], {'contracts'}, False, False),
        ]
        for paths, expected, server, native in cases:
            with self.subTest(paths=paths):
                result = classify(paths)
                self.assertEqual(select(paths), expected)
                self.assertEqual(result['gates'], sorted(expected))
                self.assertEqual(result['server_release_impact'], server)
                self.assertEqual(result['native_release_impact'], native)
                self.assertEqual(result['map_version'], 1)

    def test_shared_media_and_renames_include_every_consumer(self):
        self.assertEqual(select(['clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream/src/rnn_data.c']), set(ALL) - {'backend'})
        result = classify(['clients/web/removed.ts', 'clients/flutter/added.dart'])
        self.assertTrue(result['server_release_impact'])
        self.assertTrue(result['native_release_impact'])
        self.assertEqual(result['gates'], sorted(set(ALL) - {'backend'}))

    def test_invalid_paths_are_uncertain_not_docs(self):
        for paths in [['/docs/a'], ['docs/../backend/a'], ['docs\\a'], [''], [None]]:
            with self.subTest(paths=paths):
                self.assertEqual(select(paths), set(ALL))
