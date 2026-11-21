import json
from pathlib import Path
import unittest

from tools.qa.local_features.selection import native_targets
from .selection import requires_web_build


class PairedWebSelectionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((Path(__file__).parents[1] / 'features.json').read_text(encoding='utf8'))

    def test_android_voice_builds_the_required_web_peer(self):
        targets = native_targets(self.catalog, ['voice'], platform='android')
        self.assertTrue(requires_web_build({'android'}, targets))

    def test_unpaired_native_scenarios_do_not_add_a_web_build(self):
        targets = native_targets(self.catalog, ['auth'], platform='android')
        self.assertFalse(requires_web_build({'android'}, targets))

    def test_web_selected_already_builds_the_peer(self):
        targets = native_targets(self.catalog, ['voice'], platform='android')
        self.assertFalse(requires_web_build({'web', 'android'}, targets))

    def test_ios_does_not_select_android_pair_setup(self):
        targets = native_targets(self.catalog, ['voice'], platform='android')
        self.assertFalse(requires_web_build({'ios'}, targets))
