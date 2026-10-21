"""Warm caches never replace exact-source OCI verification or attestations."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock,patch
from . import images


class CachedImageTests(unittest.TestCase):
    def build(self,root,*,reject=False,owner=None):
        cache=Mock();cache.arguments.return_value=['--cache-from','type=local,src=/private/cache,digest=sha256:'+'c'*64,
                                                    '--cache-to','type=local,dest=/private/staging,mode=max,reset=true']
        cache.__enter__=Mock(return_value=cache);cache.__exit__=Mock(return_value=False)
        verified=Mock(side_effect=ValueError('foreign source') if reject else None,
                      return_value={'index_digest':'sha256:'+'a'*64,'image_id':'sha256:'+'c'*64})
        environment={'VITE_PUBLIC_ORIGIN':'https://qa.invalid','BOOHTACORD_SERVER_CACHE_ROOT':'/private/cache'}
        if owner is not None:environment['BOOHTACORD_BUILD_OWNER']=owner
        with patch.object(images,'LayerCache',return_value=cache),patch.object(images,'namespace',return_value='d'*64), \
                patch.object(images,'oci_root_identity',return_value='sha256:'+'a'*64,create=True), \
                patch.object(images.subprocess,'run') as run,patch.object(images.subprocess,'check_output',return_value='sha256:'+'c'*64+'\n[]'), \
                patch.object(images,'verify',verified):
            if reject:
                with self.assertRaises(ValueError):images.build(root,root,'a'*40,'b'*64,environment)
            else:images.build(root,root,'a'*40,'b'*64,environment)
        return cache,verified,run

    def test_warm_images_keep_source_labels_sbom_provenance_and_both_verifiers(self):
        with tempfile.TemporaryDirectory() as tmp:cache,verify,run=self.build(Path(tmp))
        self.assertEqual(4,verify.call_count);self.assertEqual(2,cache.publish.call_count)
        builds=[call.args[0] for call in run.call_args_list if call.args[0][:3]==['docker','buildx','build']]
        self.assertEqual(4,len(builds))
        for oci_build,docker_build in zip(builds[::2],builds[1::2]):
            for token in ('--sbom=true','--provenance=mode=max,version=v0.2'):
                self.assertIn(token,oci_build)
            self.assertIn('--sbom=false',docker_build)
            self.assertIn('--provenance=false',docker_build)
            for args in (oci_build,docker_build):
                for token in ('org.opencontainers.image.revision='+'a'*40,
                              'org.voice-platform.source-archive-sha256='+'b'*64,'--cache-from'):
                    self.assertIn(token,args)
            self.assertIn('--cache-to',oci_build)
            self.assertNotIn('--cache-to',docker_build)

    def test_owned_backend_exports_verified_oci_and_docker_archive_then_loads_docker_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);cache,verified,run=self.build(root,owner='e'*32)
        commands=[call.args[0] for call in run.call_args_list]
        self.assertEqual(6,len(commands))
        self.assertEqual('sha256:'+'a'*64,verified.call_args_list[1].args[3])
        self.assertEqual('sha256:'+'a'*64,verified.call_args_list[3].args[3])
        self.assertEqual({'docker_image_id':'sha256:'+'c'*64,'docker_rootfs_layers':[]},
                         verified.call_args_list[1].kwargs)
        self.assertEqual({'docker_image_id':'sha256:'+'c'*64,'docker_rootfs_layers':[]},
                         verified.call_args_list[3].kwargs)
        for index,service in ((0,'api'),(3,'web')):
            oci_build,docker_build=commands[index:index+2]
            self.assertEqual(['docker','buildx','build'],oci_build[:3])
            self.assertEqual(['docker','buildx','build'],docker_build[:3])
            self.assertIn(['--output',f'type=oci,dest={root/(service+".oci.tar")}'],
                          [oci_build[i:i+2] for i in range(len(oci_build)-1)])
            docker_export='type=docker,name=voice-platform-'+service+':'+'a'*40+',dest='+str(root/(service+'.docker.tar'))
            self.assertIn(['--output',docker_export],
                          [docker_build[i:i+2] for i in range(len(docker_build)-1)])
            self.assertIn('--sbom=true',oci_build)
            self.assertIn('--provenance=mode=max,version=v0.2',oci_build)
            self.assertIn('--sbom=false',docker_build)
            self.assertIn('--provenance=false',docker_build)
            for command in (oci_build,docker_build):
                self.assertIn('org.boohtacord.builder.owner='+'e'*32,command)
                self.assertIn('org.opencontainers.image.revision='+'a'*40,command)
                self.assertIn('org.voice-platform.source-archive-sha256='+'b'*64,command)
            self.assertEqual(['docker','image','load','--input',str(root/(service+'.docker.tar'))],commands[index+2])

    def test_foreign_cached_output_stops_before_cache_publication(self):
        with tempfile.TemporaryDirectory() as tmp:cache,verify,run=self.build(Path(tmp),reject=True)
        self.assertEqual(1,verify.call_count);cache.publish.assert_not_called()
        self.assertEqual(1,run.call_count)
        self.assertEqual(['docker','buildx','build'],run.call_args.args[0][:3])

    def test_npm_layer_is_independent_of_release_sha_and_go_caches_are_dependency_scoped(self):
        root=Path(__file__).resolve().parents[3]
        web=(root/'clients/web/Dockerfile').read_text();backend=(root/'backend/Dockerfile').read_text()
        self.assertLess(web.index(' npm ci'),web.index('ARG SOURCE_REVISION'))
        self.assertIn('id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-npm',web)
        for line in backend.splitlines():
            if ' go build ' in line:
                self.assertIn('target=/go/pkg/mod,sharing=locked',line)
                self.assertIn('target=/root/.cache/go-build,sharing=locked',line)
