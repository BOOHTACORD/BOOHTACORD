import unittest
from pathlib import Path
from .web import violations


class WebBoundaryTests(unittest.TestCase):
    def test_web_image_contains_vite_import_chain(self):
        root = Path(__file__).resolve().parents[3]
        dockerfile = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        copies = [line.split()[1:] for line in dockerfile.splitlines()
                  if line.startswith('COPY ') and not line.startswith('COPY --from=')]
        for source, destination in (
            ('clients/web/scripts/deepfilter_assets.mjs', './scripts/deepfilter_assets.mjs'),
            ('tools/audio/research_dfn_web/stage.mjs', '/app/tools/audio/research_dfn_web/stage.mjs'),
        ):
            self.assertTrue((root / source).is_file(), source)
            self.assertIn([source, destination], copies)

    def test_feature_cannot_import_shell_even_dynamically(self):
        sources = {'clients/web/src/voice/control.ts': ['../workspace/WorkspaceApp.vue'],
                   'clients/web/src/workspace/WorkspaceApp.vue': []}
        self.assertIn('composition', violations(sources)[0])

    def test_shared_utility_cannot_import_feature(self):
        sources = {'clients/web/src/validation/value.ts': ['../identity/session'],
                   'clients/web/src/identity/session.ts': []}
        self.assertIn('shared', violations(sources)[0])

    def test_shell_coordinates_features(self):
        sources = {'clients/web/src/workspace/WorkspaceApp.vue': ['../admin/panel/Admin.vue'],
                   'clients/web/src/admin/panel/Admin.vue': []}
        self.assertEqual(violations(sources), [])

    def test_typescript_js_specifier_resolves_typescript_source(self):
        sources = {'clients/web/src/voice/core.ts': ['./ring.js'],
                   'clients/web/src/voice/ring.ts': []}
        self.assertEqual(violations(sources), [])

    def test_typescript_substitution_keeps_feature_boundaries(self):
        sources = {'clients/web/src/shared/value.ts': ['../voice/ring.js'],
                   'clients/web/src/voice/ring.ts': []}
        self.assertIn('shared utility imports feature', violations(sources)[0])

    def test_javascript_does_not_substitute_typescript(self):
        sources = {'clients/web/src/voice/core.js': ['./ring.js'],
                   'clients/web/src/voice/ring.ts': []}
        self.assertIn('missing', violations(sources)[0])

    def test_generated_worklet_dependencies_require_their_source_contract(self):
        worklet = 'clients/web/src/voice/noise_suppression/deepfilter/worklet.js'
        core = 'clients/web/src/voice/noise_suppression/deepfilter/core.ts'
        stage = 'tools/audio/research_dfn_web/stage.mjs'
        builder = 'tools/audio/research_dfn_web/build.py'
        sources = {worklet: ['./core.js', './dfn.js'], core: [], stage: [], builder: []}
        self.assertEqual(violations(sources), [])
        for required in (core, stage, builder):
            reduced = dict(sources); del reduced[required]
            self.assertTrue(any('missing local dependency' in item for item in violations(reduced)))
        unrelated = {'clients/web/src/voice/other.js': ['./dfn.js'], stage: [], builder: []}
        self.assertIn('missing local dependency', violations(unrelated)[0])

    def test_missing_local_dependency_is_rejected(self):
        sources = {'clients/web/src/workspace/WorkspaceApp.vue': ['./gone.vue']}
        self.assertIn('missing', violations(sources)[0])

    def test_feature_can_import_shared_contract_json(self):
        sources = {'clients/web/src/voice/policy.ts': ['../../../../contracts/screen-profile.json'],
                   'contracts/screen-profile.json': []}
        self.assertEqual(violations(sources), [])
