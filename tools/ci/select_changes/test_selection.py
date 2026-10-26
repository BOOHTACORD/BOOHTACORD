import unittest
from .selection import select


class SelectionTests(unittest.TestCase):
    def test_gateway_is_verified_without_spurious_native_release(self):
        self.assertEqual(select(['support_gateway/policy.py','tests/support_gateway/test_policy.py']),{'contracts'})
    def test_docs_do_not_build_clients(self):
        self.assertEqual(select(['docs/operations.md', 'evidence/run.json']), {'contracts'})

    def test_backend_includes_release_gate(self):
        self.assertEqual(select(['backend/internal/config/runtime/load.go']), {'contracts', 'backend', 'server'})

    def test_shared_rnnoise_source_checks_web_and_native_consumers(self):
        self.assertEqual(select(['clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream/src/rnn_data.c']),
                         {'contracts', 'web', 'flutter', 'windows', 'server'})

    def test_native_changes_require_flutter_and_windows(self):
        self.assertEqual(select(['clients/flutter/lib/src/app_state.dart']), {'contracts', 'flutter', 'windows'})

    def test_contract_changes_include_every_consumer(self):
        self.assertEqual(select(['contracts/api.yaml']), set(select(None)))

    def test_unknown_path_and_toolchain_drift_are_conservative(self):
        for paths in [None, ['unexpected/runtime.conf'], ['tools/toolchains.json'], ['.github/workflows/ci.yaml']]:
            self.assertEqual(select(paths), {'contracts', 'backend', 'web', 'flutter', 'windows', 'server'})

    def test_production_config_checks_server_not_native_build(self):
        self.assertEqual(select(['deploy/compose.yaml']), {'contracts', 'backend', 'web', 'server'})

    def test_unions_both_sides_of_a_move(self):
        self.assertEqual(select(['clients/web/a.ts', 'clients/flutter/a.dart']),
                         {'contracts', 'web', 'flutter', 'windows', 'server'})

    def test_empty_diff_still_checks_contracts(self):
        self.assertEqual(select([]), {'contracts'})
