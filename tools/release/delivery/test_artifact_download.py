"""GitHub credentials are sent only to the fixed API, never to blob redirects."""
from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from . import artifact_download

TOKEN='private-token-canary'
URL='https://owned.blob.core.windows.net/path?sig=private-url-canary'


class Blob(BytesIO):
    status=200
    headers={}


class ArtifactDownloadTests(unittest.TestCase):
    def test_api_redirect_uses_token_but_blob_request_does_not(self):
        error=HTTPError('https://api.github.com/owned',302,'redirect',{'Location': URL},None)
        opener=Mock(); opener.open.side_effect=error
        self.assertEqual(URL,artifact_download.location(44,TOKEN,opener=opener))
        request=opener.open.call_args.args[0]
        self.assertEqual('Bearer '+TOKEN,request.get_header('Authorization'))
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve(); blob_opener=Mock(); blob_opener.open.return_value=Blob(b'zip-bytes')
            artifact_download.receive(URL,root/'download.zip',9,opener=blob_opener)
            request=blob_opener.open.call_args.args[0]
            self.assertIsNone(request.get_header('Authorization'))
            self.assertEqual(b'zip-bytes',(root/'download.zip').read_bytes())

    def test_redirect_does_not_allow_http_credentials_foreign_host_or_secondary_redirect(self):
        for url in ('http://owned.blob.core.windows.net/file','https://evil.test/file',
                    'https://user:pass@owned.blob.core.windows.net/file','https://owned.blob.core.windows.net:80/file'):
            opener=Mock(); opener.open.side_effect=HTTPError('api',302,'redirect',{'Location':url},None)
            with self.subTest(url=url),self.assertRaises(ValueError) as error: artifact_download.location(44,TOKEN,opener=opener)
            self.assertNotIn('canary',str(error.exception))
        with tempfile.TemporaryDirectory() as tmp:
            opener=Mock(); opener.open.side_effect=HTTPError(URL,302,'redirect',{'Location':URL},None)
            with self.assertRaises(ValueError): artifact_download.receive(URL,Path(tmp).resolve()/'download.zip',9,opener=opener)

    def test_truncated_oversized_or_changed_content_length_leaves_no_archive(self):
        for data,size,headers in [(b'short',9,{}),(b'too-long',3,{}),(b'exact',5,{'Content-Length':'6'})]:
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp).resolve(); blob=Blob(data); blob.headers=headers
                opener=Mock(); opener.open.return_value=blob
                with self.subTest(data=data),self.assertRaises(ValueError): artifact_download.receive(URL,root/'download.zip',size,opener=opener)
                self.assertFalse((root/'download.zip').exists())

    def test_invalid_artifact_id_or_token_never_starts_network(self):
        for artifact_id,token in [(True,TOKEN),(0,TOKEN),(44,''),(44,'bad\nheader')]:
            opener=Mock()
            with self.assertRaises(ValueError): artifact_download.location(artifact_id,token,opener=opener)
            opener.open.assert_not_called()
