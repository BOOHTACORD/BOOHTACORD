"""Safety boundaries for automatic release artifact retention."""
import fcntl
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import catalog, policy, run


def revision(n): return f'{n:040x}'

def manifest(n):
    return {'source_revision': revision(n), 'components': {s: {'archive': s+'.oci.tar', 'index_digest': 'sha256:'+f'{n*2+i:064x}'} for i,s in enumerate(('api','web'))}, 'files': {s+'.oci.tar': {'bytes': 3} for s in ('api','web')}}


class RetentionTests(unittest.TestCase):
    def test_keeps_ten_newest_plus_current_rollback_and_every_container_reference(self):
        rows=[{'revision':revision(n),'time':n} for n in range(1,21)]
        keep=policy.retained(rows,revision(1),revision(2),{revision(3)},10)
        self.assertEqual({revision(n) for n in range(11,21)}|{revision(1),revision(2),revision(3)},keep)

    def test_missing_current_or_previous_stops_the_whole_plan(self):
        rows=[{'revision':revision(1),'time':1}]
        for current,previous in [(revision(2),revision(1)),(revision(1),revision(2))]:
            with self.subTest(current=current),self.assertRaises(ValueError):
                policy.retained(rows,current,previous,set(),10)

    def test_retention_cannot_be_reduced_below_ten(self):
        with self.assertRaises(ValueError):policy.retained([],revision(1),revision(2),set(),1)

    def test_image_candidates_exclude_retained_digests_and_all_container_image_ids(self):
        rows=[{'revision':revision(n),'manifest':manifest(n)} for n in (1,2,3)]
        refs={policy.reference(s,m['components'][s]['index_digest']):'sha256:'+f'{n*2+i:064x}' for n in (1,2,3) for m in [manifest(n)] for i,s in enumerate(('api','web'))}
        in_use={refs[policy.reference('api',manifest(1)['components']['api']['index_digest'])]}
        candidates=policy.image_candidates(rows,{revision(3)},refs,in_use)
        self.assertEqual(3,len(candidates))
        self.assertFalse(any(refs[r] in in_use for r in candidates))
        self.assertFalse(any(r in candidates for r in refs if refs[r] in {refs[policy.reference(s,manifest(3)['components'][s]['index_digest'])] for s in ('api','web')}))

    def test_shared_image_id_of_a_retained_release_is_protected(self):
        rows=[{'revision':revision(n),'manifest':manifest(n)} for n in (1,2)]
        refs={policy.reference(s,m['components'][s]['index_digest']):'sha256:'+'f'*64 for m in (manifest(1),manifest(2)) for s in ('api','web')}
        self.assertEqual([],policy.image_candidates(rows,{revision(2)},refs,set()))


class FilesystemTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.directory=self.root/revision(1);self.directory.mkdir()
        self.document=self.directory/'manifest.json';self.document.write_text(json.dumps(manifest(1)))
        (self.directory/'manifest.json.sig').write_text('signature')
        for service in ('api','web'):(self.directory/(service+'.oci.tar')).write_bytes(b'oci')

    def inventory(self):
        with patch.object(catalog,'verify'),patch.object(catalog,'validate'):
            return catalog.inventory(self.root,Path('/trusted-key'))

    def test_archive_deletion_does_not_change_release_age(self):
        before=self.inventory()[0]['time']
        catalog.remove_archives(self.inventory()[0])
        self.assertEqual(before,self.inventory()[0]['time'])
        self.assertTrue(self.document.exists())
        self.assertFalse((self.directory/'api.oci.tar').exists())
        self.assertEqual(0,catalog.remove_archives(self.inventory()[0]))

    def test_reinstalling_current_version_keeps_the_latest_other_successful_release(self):
        current=revision(1);previous=revision(2)
        (self.directory/'deployment-readback.json').write_text(json.dumps({'status':'PASS','source_revision':current,'previous_source_revision':current}))
        old=self.root/previous;old.mkdir()
        (old/'installed.json').write_text(json.dumps({'status':'PASS','source_revision':previous}))
        self.assertEqual(previous,catalog.previous(self.root,current))

    def test_unsigned_release_causes_no_deletion(self):
        with patch.object(catalog,'verify',side_effect=ValueError('invalid signature')),self.assertRaises(ValueError):
            catalog.inventory(self.root,Path('/trusted-key'))
        self.assertTrue((self.directory/'api.oci.tar').exists())

    def test_symlinked_release_is_rejected(self):
        (self.root/revision(2)).symlink_to(self.directory,target_is_directory=True)
        with self.assertRaises(ValueError):self.inventory()

    def test_archive_symlinks_hardlinks_and_changed_size_are_rejected_before_any_deletion(self):
        p=self.directory/'web.oci.tar'
        for mode in ('symlink','hardlink','size'):
            with self.subTest(mode=mode):
                p.unlink();target=self.root/'protected';target.write_bytes(b'oci')
                if mode=='symlink':p.symlink_to(target)
                elif mode=='hardlink':os.link(target,p)
                else:p.write_bytes(b'bad-size')
                with self.assertRaises(ValueError):self.inventory()
                self.assertTrue((self.directory/'api.oci.tar').exists());self.assertEqual(b'oci',target.read_bytes())
                p.unlink();p.write_bytes(b'oci')

    def test_container_snapshot_ignores_order_but_detects_changed_bind_mount(self):
        first={'id':'one','image':'sha256:'+'a'*64,'mounts':[{'Source':'/a'},{'Source':'/b'}]}
        second={**first,'mounts':list(reversed(first['mounts']))}
        with patch.object(run,'docker',side_effect=['one',json.dumps(first),'one',json.dumps(second)]):
            self.assertEqual(run.containers(),run.containers())
        second={**first,'mounts':[{'Source':'/changed'},{'Source':'/b'}]}
        with patch.object(run,'docker',side_effect=['one',json.dumps(first),'one',json.dumps(second)]):
            self.assertNotEqual(run.containers(),run.containers())

    def test_busy_installer_lock_skips_without_docker_or_mutation(self):
        with (self.root/'.install.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with patch.object(run,'RELEASE_ROOT',self.root),patch.object(run,'docker') as docker:
                self.assertEqual('SKIPPED_BUSY',run.rotate(apply=True)['status'])
                docker.assert_not_called()

    def test_dry_run_never_deletes_archives_or_docker_images(self):
        with patch.object(run,'locked_plan',return_value=({'status':'PLAN'},[],[],[])),patch.object(run,'docker') as docker:
            with patch.object(run,'RELEASE_ROOT',self.root):
                self.assertEqual('PLAN',run.rotate(apply=False)['status'])
            docker.assert_not_called()
        self.assertTrue((self.directory/'api.oci.tar').exists())


if __name__=='__main__':unittest.main()
