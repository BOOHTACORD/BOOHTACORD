"""A private cache never admits linked, changed, foreign or cross-dependency data."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from .layer_cache import LayerCache, namespace


def exported(path, data=b'public-build-layer'):
    blobs=path/'blobs/sha256';blobs.mkdir(parents=True,exist_ok=True)
    digest=hashlib.sha256(data).hexdigest();(blobs/digest).write_bytes(data)
    (path/'oci-layout').write_text('{"imageLayoutVersion":"1.0.0"}')
    (path/'index.json').write_text(json.dumps({'schemaVersion':2,'manifests':[{'digest':'sha256:'+digest}]}))


@unittest.skipUnless(os.name=='posix','The trusted Linux builder requires POSIX ownership and locking')
class LayerCacheTests(unittest.TestCase):
    def test_verified_digest_is_reused_and_corruption_becomes_a_cold_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve()/'cache'
            with LayerCache(root) as cache:
                self.assertNotIn('--cache-from',cache.arguments('api','a'*64))
                exported(cache.staging('api'));cache.publish('api','a'*64)
            with LayerCache(root) as cache:
                args=cache.arguments('api','a'*64)
                self.assertIn('--cache-from',args);self.assertIn('digest=sha256:',args[1])
                for p in (root/'api/blobs/sha256').iterdir():p.write_bytes(b'changed')
                self.assertNotIn('--cache-from',cache.arguments('api','a'*64))
                self.assertEqual('REJECTED',cache.report['api']['import'])

    def test_another_namespace_is_cold_and_each_publish_replaces_old_blobs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve()/'cache'
            with LayerCache(root) as cache:
                cache.arguments('web','a'*64);exported(cache.staging('web'));cache.publish('web','a'*64)
                self.assertNotIn('--cache-from',cache.arguments('web','b'*64))
                exported(cache.staging('web'),b'new-layer');cache.publish('web','b'*64)
                self.assertEqual(1,len(list((root/'web/blobs/sha256').iterdir())))

    def test_foreign_linked_or_concurrently_locked_root_is_not_used(self):
        with tempfile.TemporaryDirectory() as tmp:
            parent=Path(tmp).resolve();external=parent/'external';external.mkdir()
            link=parent/'linked';link.symlink_to(external,target_is_directory=True)
            with self.assertRaises(ValueError):
                with LayerCache(link):pass
            with LayerCache(parent/'cache'):
                with self.assertRaises(ValueError):
                    with LayerCache(parent/'cache'):pass
            (parent/'foreign').mkdir()
            with self.assertRaises(ValueError):
                with LayerCache(parent/'foreign'):pass

    def test_oversized_export_is_rejected_before_becoming_reusable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve()/'cache'
            with LayerCache(root,max_bytes=10) as cache:
                cache.arguments('api','a'*64);exported(cache.staging('api'))
                with self.assertRaises(ValueError):cache.publish('api','a'*64)
                self.assertFalse((root/'api').exists())

    def test_linked_metadata_cannot_redirect_a_future_publication_outside_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            parent=Path(tmp).resolve();root=parent/'cache'
            with LayerCache(root):pass
            target=parent/'foreign';target.write_text('preserve')
            (root/'api.meta.tmp').symlink_to(target)
            with self.assertRaises(ValueError):
                with LayerCache(root):pass
            self.assertEqual('preserve',target.read_text())

    def test_namespace_changes_with_lockfile_and_toolchain_not_revision_labels(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in ('tools/toolchains.json','backend/Dockerfile','backend/go.mod','backend/go.sum'):
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('public-input')
            original=namespace(root,'api')
            (root/'unrelated').write_text('another-commit')
            self.assertEqual(original,namespace(root,'api'))
            (root/'backend/go.sum').write_text('updated-lock')
            self.assertNotEqual(original,namespace(root,'api'))
