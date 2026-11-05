"""Only the compiler digest acquired by this hosted bundle job may be released."""
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
from tools.audio.asset_build import COMPILER_IMAGE
from .asset_storage import build_release_assets

REFERENCE=COMPILER_IMAGE.split(':4.0.20')[0]+COMPILER_IMAGE.split(':4.0.20')[1]
HOSTED={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted'}

class AssetStorageTests(unittest.TestCase):
    def execute(self, before='', after='', error=None):
        with patch.dict('os.environ',HOSTED,clear=True), \
             patch('tools.build.server.asset_storage.subprocess.check_output',side_effect=[before,after]), \
             patch('tools.build.server.asset_storage.subprocess.run') as remove, \
             patch('tools.build.server.asset_storage.build_assets',side_effect=error) as build:
            if error:
                with self.assertRaises(type(error)):build_release_assets(Path('/source'))
                result=None
            else:result=build_release_assets(Path('/source'))
            build.assert_called_once_with(Path('/source'))
            return result,remove.call_args_list

    def test_fresh_unused_compiler_is_released_by_exact_digest_without_force(self):
        result,calls=self.execute(after=REFERENCE+'\n')
        self.assertTrue(result['removed_new_compiler_reference'])
        self.assertEqual(calls[0].args[0],['docker','image','rm',REFERENCE])
        self.assertTrue(calls[0].kwargs['check'])

    def test_preexisting_compiler_and_foreign_images_are_preserved(self):
        result,calls=self.execute(before=REFERENCE+'\n')
        self.assertEqual(calls,[])
        self.assertFalse(result['removed_new_compiler_reference'])
        _,calls=self.execute(before='other/image@sha256:foreign\n',after='other/image@sha256:foreign\n')
        self.assertEqual(calls,[])

    def test_compiler_failure_still_cleans_its_new_reference(self):
        _,calls=self.execute(after=REFERENCE+'\n',error=RuntimeError('compile failed'))
        self.assertEqual(calls[0].args[0],['docker','image','rm',REFERENCE])

    def test_local_or_self_hosted_builds_never_remove_images(self):
        for env in ({},{'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'self-hosted'}):
            with self.subTest(env=env),patch.dict('os.environ',env,clear=True), \
                 patch('tools.build.server.asset_storage.build_assets') as build, \
                 patch('tools.build.server.asset_storage.subprocess.check_output') as inspect:
                build_release_assets(Path('/source'))
                build.assert_called_once()
                inspect.assert_not_called()

    def test_failed_removal_is_not_reported_as_success(self):
        with patch.dict('os.environ',HOSTED,clear=True), \
             patch('tools.build.server.asset_storage.subprocess.check_output',side_effect=['',REFERENCE+'\n']), \
             patch('tools.build.server.asset_storage.build_assets'), \
             patch('tools.build.server.asset_storage.subprocess.run',side_effect=subprocess.CalledProcessError(1,['docker'])):
            with self.assertRaises(subprocess.CalledProcessError):build_release_assets(Path('/source'))
