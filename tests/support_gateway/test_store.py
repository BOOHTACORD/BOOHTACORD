import tempfile
import unittest
from pathlib import Path
from support_gateway.store import Store

class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.store=Store(Path(self.tmp.name))
    def tearDown(self):self.tmp.cleanup()
    def message(self, **changes):
        return {'operation_id':'a'*32,'conversation':'b'*32,'body':'Synthetic public request','consent_version':1,'files':[],**changes}
    def test_replay_is_idempotent_and_changed_payload_is_rejected(self):
        first=self.store.submit('tenant-one',self.message())
        self.assertEqual(first,self.store.submit('tenant-one',self.message()))
        with self.assertRaises(ValueError):self.store.submit('tenant-one',self.message(body='changed'))
        self.assertEqual(1,len(self.store.pending()))
    def test_same_conversation_id_cannot_cross_installations(self):
        self.store.submit('tenant-one',self.message());self.store.submit('tenant-two',self.message())
        jobs=self.store.pending();self.assertEqual(2,len(jobs))
        self.assertNotEqual(jobs[0]['marker'],jobs[1]['marker'])
        self.store.published(jobs[0]['id'],17,100)
        self.store.reply(17,101,'Synthetic operator reply')
        self.assertEqual(1,len(self.store.replies('tenant-one',0)))
        self.assertEqual([],self.store.replies('tenant-two',0))
    def test_forwarded_comment_is_not_echoed_and_reply_is_idempotent(self):
        self.store.submit('tenant-one',self.message());job=self.store.pending()[0]
        self.store.published(job['id'],17,100)
        self.assertFalse(self.store.reply(17,100,'Synthetic echo'))
        self.assertTrue(self.store.reply(17,101,'Synthetic reply'))
        self.assertFalse(self.store.reply(17,101,'Synthetic reply'))
        self.assertEqual([],self.store.replies('tenant-one',101))
    def test_missing_blobs_and_stale_consent_never_queue(self):
        with self.assertRaises(ValueError):self.store.submit('tenant',self.message(consent_version=0))
        with self.assertRaises(ValueError):self.store.submit('tenant',self.message(files=[dict(name='x.txt',size=1,sha256='c'*64)]))
        self.assertEqual([],self.store.pending())
    def test_nonce_replay_rejected(self):
        self.store.nonce('tenant','a'*32,100)
        with self.assertRaises(ValueError):self.store.nonce('tenant','a'*32,100)
    def test_rolling_upgrade_adds_author_without_duplicate_or_changed_content(self):
        first=self.store.submit('tenant',self.message())
        user_id='10000000-0000-4000-8000-000000000001'
        self.assertEqual(first,self.store.submit('tenant',self.message(user_id=user_id)))
        self.assertEqual(first,self.store.submit('tenant',self.message()))
        self.assertEqual(user_id,self.store.author('tenant','b'*32))
        with self.assertRaises(ValueError):self.store.submit('tenant',self.message(user_id='20000000-0000-4000-8000-000000000002'))
        with self.assertRaises(ValueError):self.store.submit('tenant',self.message(user_id=user_id,body='Changed'))
        self.assertEqual(1,len(self.store.pending()))
    def test_legacy_author_lookup_is_isolated_by_installation_and_conversation(self):
        user_id='10000000-0000-4000-8000-000000000001'
        self.store.submit('tenant',self.message(user_id=user_id))
        self.assertIsNone(self.store.author('another-tenant','b'*32))
        self.assertIsNone(self.store.author('tenant','c'*32))
    def test_deleted_route_reset_does_not_touch_other_installation(self):
        first=self.store.submit('tenant-one',self.message())
        second=self.store.submit('tenant-two',self.message())
        self.store.published(first,17);self.store.published(second,23)
        follow=self.store.submit('tenant-one',self.message(operation_id='c'*32))
        self.store.publishing(follow,17);self.store.missing(follow,17)
        self.assertFalse(self.store.reply(17,101,'Synthetic stale reply'))
        self.assertTrue(self.store.reply(23,102,'Synthetic isolated reply'))
        self.assertEqual([],self.store.replies('tenant-one',0))
        self.assertEqual(1,len(self.store.replies('tenant-two',0)))
    def test_private_to_public_cancels_old_unsent_payload_and_allows_fresh_consent(self):
        self.store.visibility(True);self.store.submit('tenant',self.message())
        self.store.visibility(False)
        self.assertEqual(2,self.store.notice());self.assertEqual([],self.store.pending())
        self.store.submit('tenant',self.message(operation_id='c'*32,consent_version=2))
        self.assertEqual(1,len(self.store.pending()))

if __name__=='__main__':unittest.main()
