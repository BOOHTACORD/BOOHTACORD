import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
from tools.release.client_updates.catalog import mutate
from tools.release.client_updates.test_catalog import source,target


class PublicCatalogPublicationPermissionsTests(unittest.TestCase):
    def test_atomic_publication_preserves_readability_and_other_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=source(Path(tmp),target()|{'release_id':'windows-r61','release_order':61})
            document=json.loads(path.read_text());other={'platform':'android','distribution':'direct','channel':'stable','arch':'arm64','state':'unconfigured','target':None}
            document['entries'].append(other);path.write_text(json.dumps(document));path.chmod(0o644)
            old=os.umask(0o077)
            try:result=mutate(path,4,('windows','direct','stable','x64'),'published',target()|{'release_id':'windows-r62','release_order':62})
            finally:os.umask(old)
            self.assertEqual(result['catalog_revision'],5);self.assertEqual(result['entries'][1],other)
            self.assertEqual(result['entries'][0]['target']['release_order'],62)
            if os.name=='posix':self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o644)

    def test_private_lock_and_atomic_replace_contract_are_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=source(Path(tmp));original=os.replace;observed=[]
            def replace(left,right):
                observed.append((stat.S_IMODE(path.with_suffix('.json.lock').stat().st_mode),stat.S_IMODE(Path(left).stat().st_mode)))
                original(left,right)
            with patch('tools.release.client_updates.catalog.os.replace',side_effect=replace):
                mutate(path,4,('windows','direct','stable','x64'),'published',target())
            self.assertEqual(len(observed),1)
            if os.name=='posix':self.assertEqual(observed[0],(0o600,0o644))
            self.assertFalse(path.with_suffix('.json.lock').exists())
