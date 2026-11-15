import unittest
import hashlib
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
from . import signing



class SigningOrderTests(unittest.TestCase):
    def test_signature_is_applied_before_the_digest_is_published(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            dll = output / 'boohta_deepfilter.dll'
            dll.write_bytes(b'unsigned')
            (output / 'engine.json').write_text('{}', encoding='utf-8')
            def sign(path, config):
                path.write_bytes(b'signed')
            with patch.object(signing, 'configuration', return_value={'thumbprint': 'test'}), \
                 patch.object(signing, 'owned_signature', side_effect=[False, True]), \
                 patch.object(signing, 'sign_file', side_effect=sign):
                assert signing.prepare(output) == output
            assert json.loads((output / 'engine.json').read_text())['dllSha256'] == hashlib.sha256(b'signed').hexdigest()
