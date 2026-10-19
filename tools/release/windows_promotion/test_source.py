"""Actual Git candidate diffs cannot silently include other changes or stale catalogs."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from . import intent, prepare, check_source
from .test_intent import catalogs


class SourceTests(unittest.TestCase):
    def test_real_git_candidate_reuse_and_stale_or_rewritten_intent_rejected(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            def git(*args):return subprocess.check_output(['git',*args],cwd=root,stderr=subprocess.DEVNULL,text=True).strip()
            git('init','-q');git('config','user.email','fixture@example.invalid');git('config','user.name','Fixture')
            before,after=catalogs();catalog=root/intent.PATH;catalog.parent.mkdir(parents=True);catalog.write_bytes(intent.raw(before))
            git('add','deploy');git('commit','-qm','base');base=git('rev-parse','HEAD')
            record=intent.create(intent.raw(before),intent.raw(after),base,{'tag':'windows-v1.0.39','source_revision':'b'*40,
                'manifest_sha256':'c'*64,'archive_sha256':'d'*64,'checksums_sha256':'e'*64,'asset_inventory_sha256':'f'*64})
            path=root/(intent.DIRECTORY+intent.identifier(record)+'.json');path.parent.mkdir();path.write_bytes(intent.raw(record))
            catalog.write_bytes(intent.raw(after));git('add','deploy');git('commit','-qm','candidate');sha=git('rev-parse','HEAD')
            with patch.object(prepare,'ROOT',root),patch.object(check_source,'ROOT',root):
                prepare.verify_branch(record,sha);check_source.validate(base,sha)
                git('checkout','--detach',base);before['catalog_revision']=30;catalog.write_bytes(intent.raw(before))
                git('add','deploy');git('commit','-qm','racing promotion');stale=git('rev-parse','HEAD')
                with self.assertRaises(ValueError):check_source.validate(stale,sha)
                git('checkout','--detach',sha);path.write_text('{}');git('add','deploy');git('commit','-qm','rewrite')
                with self.assertRaises(ValueError):prepare.verify_branch(record,git('rev-parse','HEAD'))
                with self.assertRaises(ValueError):check_source.validate(sha,git('rev-parse','HEAD'))
