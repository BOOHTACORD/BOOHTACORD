"""Warm caches never replace exact-source OCI verification or attestations."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock,patch
from . import images


class CachedImageTests(unittest.TestCase):
    def build(self,root,*,reject=False):
        cache=Mock();cache.arguments.return_value=['--cache-from','type=local,src=/private/cache,digest=sha256:'+'c'*64]
        cache.__enter__=Mock(return_value=cache);cache.__exit__=Mock(return_value=False)
        verified=Mock(side_effect=ValueError('foreign source') if reject else None,return_value={'index_digest':'sha256:'+'a'*64})
        with patch.object(images,'LayerCache',return_value=cache),patch.object(images,'namespace',return_value='d'*64), \
                patch.object(images.subprocess,'run') as run,patch.object(images.subprocess,'check_output',return_value='sha256:'+'a'*64), \
                patch.object(images,'verify',verified):
            if reject:
                with self.assertRaises(ValueError):images.build(root,root,'a'*40,'b'*64,{'VITE_PUBLIC_ORIGIN':'https://qa.invalid','BOOHTACORD_SERVER_CACHE_ROOT':'/private/cache'})
            else:images.build(root,root,'a'*40,'b'*64,{'VITE_PUBLIC_ORIGIN':'https://qa.invalid','BOOHTACORD_SERVER_CACHE_ROOT':'/private/cache'})
        return cache,verified,run

    def test_warm_images_keep_source_labels_sbom_provenance_and_both_verifiers(self):
        with tempfile.TemporaryDirectory() as tmp:cache,verify,run=self.build(Path(tmp))
        self.assertEqual(2,verify.call_count);self.assertEqual(2,cache.publish.call_count)
        for call in run.call_args_list:
            args=call.args[0]
            for token in ('--sbom=true','--provenance=mode=max,version=v0.2','org.opencontainers.image.revision='+'a'*40,
                          'org.voice-platform.source-archive-sha256='+'b'*64,'--cache-from'):
                self.assertIn(token,args)

    def test_foreign_cached_output_stops_before_cache_publication(self):
        with tempfile.TemporaryDirectory() as tmp:cache,verify,run=self.build(Path(tmp),reject=True)
        self.assertEqual(1,verify.call_count);cache.publish.assert_not_called()

    def test_npm_layer_is_independent_of_release_sha_and_go_caches_are_dependency_scoped(self):
        root=Path(__file__).resolve().parents[3]
        web=(root/'clients/web/Dockerfile').read_text();backend=(root/'backend/Dockerfile').read_text()
        self.assertLess(web.index(' npm ci'),web.index('ARG SOURCE_REVISION'))
        self.assertIn('id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-npm',web)
        for line in backend.splitlines():
            if ' go build ' in line:
                self.assertIn('target=/go/pkg/mod,sharing=locked',line)
                self.assertIn('target=/root/.cache/go-build,sharing=locked',line)
