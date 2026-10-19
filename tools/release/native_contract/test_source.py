"""Stable releases must bind the approved version to an exact trusted tag commit."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from . import source


class SourceTests(unittest.TestCase):
    def test_tag_version_and_source_mismatch_fail(self):
        identity={'version':'1.2.3','native_build':'4'}
        env={'GITHUB_REPOSITORY':'Egkurilov/BOOHTACORD','GITHUB_REF':'refs/tags/windows-v1.2.3',
             'GITHUB_SHA':'a'*40,'GITHUB_ACTIONS':'true','GITHUB_RUN_ID':'12','GITHUB_RUN_ATTEMPT':'1'}
        with patch.object(source,'load',return_value=identity),patch.object(source,'output',return_value='a'*40), \
             patch.object(source.subprocess,'run') as run,patch.dict(os.environ,env,clear=True):
            self.assertEqual(source.preflight('windows')['tag'],'windows-v1.2.3')
            for key,bad in [('GITHUB_REF','refs/heads/master'),('GITHUB_REF','refs/tags/windows-v9.9.9'),
                            ('GITHUB_SHA','b'*40),('GITHUB_REPOSITORY','other/repo')]:
                with patch.dict(os.environ,{key:bad}),self.subTest(key=key):
                    if key=='GITHUB_SHA':
                        with patch.object(source,'output',side_effect=['a'*40,'b'*40]),self.assertRaises(ValueError):source.preflight('windows')
                    else:
                        with self.assertRaises(ValueError):source.preflight('windows')
            run.side_effect=subprocess.CalledProcessError(1,['git'])
            with self.assertRaises(subprocess.CalledProcessError):source.preflight('windows')

    def test_annotated_tag_and_master_ancestry_are_checked_with_real_git(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            def git(*args):return subprocess.check_output(['git',*args],cwd=root,stderr=subprocess.DEVNULL,text=True).strip()
            git('init','-q');git('config','user.email','fixture@example.invalid');git('config','user.name','Fixture')
            (root/'fixture').write_text('a');git('add','fixture');git('commit','-qm','fixture')
            revision=git('rev-parse','HEAD');git('update-ref','refs/remotes/origin/master',revision)
            git('tag','-a','windows-v1.2.3','-m','fixture')
            def output(*args):return git(*args[1:])
            original=subprocess.run
            def run(args,**kwargs):return original(args,**{**kwargs,'cwd':root})
            with patch.object(source,'ROOT',root),patch.object(source,'output',side_effect=output), \
                 patch.object(source,'load',return_value={'version':'1.2.3','native_build':'4'}), \
                 patch.object(source.subprocess,'run',side_effect=run),patch.dict(os.environ,{
                    'GITHUB_REPOSITORY':'Egkurilov/BOOHTACORD','GITHUB_REF':'refs/tags/windows-v1.2.3',
                    'GITHUB_SHA':revision,'GITHUB_ACTIONS':'true','GITHUB_RUN_ID':'12','GITHUB_RUN_ATTEMPT':'1'},clear=True):
                self.assertEqual(source.preflight('windows')['source_revision'],revision)
                with patch.dict(os.environ,GITHUB_SHA=git('rev-parse','refs/tags/windows-v1.2.3')):
                    self.assertEqual(source.preflight('windows')['source_revision'],revision)
                git('checkout','--orphan','foreign');git('commit','--allow-empty','-qm','foreign')
                git('update-ref','refs/remotes/origin/master',git('rev-parse','HEAD'))
                git('checkout','--detach',revision)
                with self.assertRaises(subprocess.CalledProcessError):source.preflight('windows')

    def test_candidate_master_never_claims_a_verified_release_tag(self):
        with patch.object(source,'load',return_value={'version':'1.2.3','native_build':'4'}), \
             patch.object(source,'output',return_value='a'*40),patch.object(source.subprocess,'run'),patch.dict(os.environ,{
                'GITHUB_REPOSITORY':'Egkurilov/BOOHTACORD','GITHUB_REF':'refs/heads/master','GITHUB_SHA':'a'*40,
                'GITHUB_EVENT_NAME':'workflow_dispatch','NATIVE_RELEASE_DRY_RUN':'true'},clear=True):
            value=source.preflight('android')
            self.assertEqual(value['release_mode'],'candidate');self.assertFalse(value['tag_verified'])
            with patch.dict(os.environ,GITHUB_REF='refs/heads/foreign'),self.assertRaises(ValueError):source.preflight('android')
            with patch.dict(os.environ,NATIVE_RELEASE_DRY_RUN='false'),self.assertRaises(ValueError):source.preflight('android')
