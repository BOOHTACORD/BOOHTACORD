"""Every critical area selects actual runtime coverage; unknown changes select all."""
import unittest
from . import plan


class PlanTests(unittest.TestCase):
    def test_critical_areas_and_explicit_non_runtime_documentation(self):
        for path in ('backend/internal/identity/login.go','backend/internal/authorization/acl.go',
                     'backend/internal/chat/dm.go','clients/web/src/voice/room.ts','clients/web/src/conversation/chat.ts',
                     'clients/flutter/lib/src/features/updates/desktop/controller.dart','contracts/openapi.yaml'):
            with self.subTest(path=path):self.assertTrue(plan.select([path])['profiles'])
        self.assertEqual(plan.select(['docs/contributing.md'])['profiles'],[])
        product_catalog = plan.select(['product-map/features/realtime/core.yaml'])
        self.assertEqual(product_catalog['profiles'],[])
        self.assertEqual(product_catalog['release_required'],[])
        self.assertEqual(product_catalog['physical_required'],[])
        self.assertFalse(product_catalog['uncertain'])
        self.assertEqual(plan.select(['tools/qa/local_features/features.json'])['profiles'],[])
        for path in ('tools/qa/critical_client_acceptance/issue785_android_flutter_uplink_pair.py',
                     'tools/qa/critical_client_acceptance/test_issue785_android_flutter_uplink_pair.py',
                     'tools/ci/select_changes/dependencies.json',
                     'tools/ci/select_changes/test_routing.py',
                     'tools/ci/actual_acceptance/plan-v1.json',
                     'tools/ci/actual_acceptance/test_plan.py',
                     'tools/verify/livekit_network_config/check.py'):
            with self.subTest(path=path):
                result = plan.select([path])
                self.assertEqual(result['profiles'], [])
                self.assertEqual(result['release_required'], [])
                self.assertEqual(result['physical_required'], [])
                self.assertFalse(result['uncertain'])
        self.assertEqual(plan.select(['new-unknown/file'])['profiles'],list(plan.PROFILES))
        self.assertEqual(plan.select(None)['profiles'],list(plan.PROFILES))
        self.assertTrue(plan.select(['clients/flutter/lib/src/features/updates/desktop/controller.dart'])['release_required'])

    def test_auth_acl_dm_and_media_have_no_special_case_hole(self):
        for path in ('backend/internal/identity/reset/main.go','backend/internal/authorization/main.go',
                     'backend/internal/chat/list_direct_message_history/a.go','backend/internal/media/publish/a.go'):
            self.assertEqual(plan.select([path])['profiles'],list(plan.PROFILES))
        self.assertIn('next',plan.select(['clients/web/src/direct_message/history.ts'])['profiles'])
        self.assertIn('sfu',plan.select(['clients/web/src/screen/dialog.vue'])['profiles'])
