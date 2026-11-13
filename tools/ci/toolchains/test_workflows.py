from pathlib import Path
import unittest
import yaml
from .workflows import validate

ROOT = Path(__file__).resolve().parents[3]


class ToolchainWorkflowTests(unittest.TestCase):
    def documents(self):
        return {p.name: yaml.load(p.read_text(), Loader=yaml.BaseLoader)
                for p in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_actual_sdk_and_dependency_cache_contract(self):
        validate(self.documents(), ROOT)

    def test_research_windows_browser_exception_is_narrow(self):
        for mutation in ('platform', 'browser', 'cache'):
            documents = self.documents()
            job = documents['audio-web-research.yaml']['jobs']['windows-wasm']
            steps = job['steps']
            if mutation == 'platform': job['runs-on'] = 'ubuntu-24.04'
            if mutation == 'browser':
                step = next(s for s in steps if 'npx playwright install chromium firefox' in s.get('run', ''))
                step['run'] = step['run'].replace('npx playwright install chromium firefox', 'npx playwright install chromium')
            if mutation == 'cache':
                step = next(s for s in steps if s.get('uses', '').startswith('actions/setup-node@'))
                step['with'].pop('cache-dependency-path', None)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): validate(documents, ROOT)

    def test_wrong_sdk_key_or_conditional_install_is_rejected(self):
        for mutation in ('go', 'npm', 'skip'):
            documents = self.documents()
            steps = documents['ci-backend.yaml' if mutation == 'go' else 'ci-frontend.yaml']['jobs']['static' if mutation == 'go' else 'fast']['steps']
            with self.subTest(mutation=mutation):
                if mutation == 'go': next(s for s in steps if s.get('uses', '').startswith('actions/setup-go@'))['with']['go-version'] = '1.26.0'
                if mutation == 'npm': next(s for s in steps if s.get('uses', '').startswith('actions/setup-node@'))['with']['cache-dependency-path'] = 'clients/web/package-lock.json'
                if mutation == 'skip': next(s for s in steps if 'tools.ci.web_suites.run' in s.get('run', ''))['if'] = "steps.cache.outputs.cache-hit != 'true'"
                with self.assertRaises(ValueError): validate(documents, ROOT)
