from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT = Path(__file__).resolve().parents[3]


class FlutterCompositeContractTests(unittest.TestCase):
    def source(self):
        return yaml.load((ROOT / '.github/actions/flutter-setup/action.yaml').read_text(), Loader=yaml.BaseLoader)

    def test_public_sdk_cache_does_not_cache_pub_or_skip_verification(self):
        validate(self.source(), ROOT)

    def test_mutable_installer_private_cache_and_cache_hit_bypasses_are_rejected(self):
        for mutation in ('source', 'pub', 'skip', 'cache-write'):
            document = self.source()
            with self.subTest(mutation=mutation):
                if mutation == 'source': document['runs']['steps'][1]['with']['ref'] = 'master'
                if mutation == 'pub': document['runs']['steps'][2]['with']['path'] = '~/.pub-cache'
                if mutation == 'skip': document['runs']['steps'][3]['if'] = "steps.sdk-cache.outputs.cache-hit != 'true'"
                if mutation == 'cache-write': document['runs']['steps'][-1]['if'] = 'always()'
                with self.assertRaises(ValueError): validate(document, ROOT)
