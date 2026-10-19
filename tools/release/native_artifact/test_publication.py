import json
import tempfile
import unittest
from pathlib import Path
from tools.release.native_contract.test_assets import fixture
from tools.release.native_contract.assets import validate


class AndroidPublicationTests(unittest.TestCase):
    def test_release_publishes_every_component_file_referenced_by_manifest(self):
        with tempfile.TemporaryDirectory() as name:
            directory,context=fixture(Path(name),'android')
            contract=validate(directory,context)
            component=json.loads((directory/'artifact-manifest.json').read_text())['audio_component']
            self.assertTrue({component['sbom'],component['license']} <= contract['assets'].keys())
