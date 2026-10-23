import tempfile
import unittest
from pathlib import Path
from support_gateway.store import Store
from support_gateway.publisher import Publisher

class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.store=Store(Path(self.tmp.name));self.calls=[]
        self.store.submit('tenant',dict(operation_id='a'*32,conversation='b'*32,body='Synthetic request',consent_version=1,files=[]))
        self.publisher=Publisher(self.store,self.broker)
    def tearDown(self):self.tmp.cleanup()
    def broker(self,operation,**data):
        self.calls.append((operation,data))
        if operation=='repository':return dict(private=False)
        if operation=='create_issue':return dict(issue=17)
        if operation=='create_comment':return dict(id=100,issue=data['issue'])
        if operation=='issue':return dict(exists=True)
        if operation=='find_operation':return None
        if operation=='comments':return []
        if operation=='permission':return dict(permission='write')
        raise AssertionError(operation)
    def test_first_message_issue_next_comment_with_no_local_metadata(self):
        self.publisher.publish()
        posted=[data for op,data in self.calls if op=='create_issue'][0]
        self.assertNotIn('tenant',posted['body']);self.assertNotIn('b'*32,posted['body'])
        self.store.submit('tenant',dict(operation_id='c'*32,conversation='b'*32,body='Synthetic follow-up',consent_version=1,files=[]))
        self.publisher.publish()
        self.assertEqual(1,len([1 for op,_ in self.calls if op=='create_issue']))
        self.assertEqual(17,[d for op,d in self.calls if op=='create_comment'][0]['issue'])
    def test_uncertain_post_reconciles_never_blindly_retries(self):
        self.store.publishing(self.store.pending()[0]['id'])
        self.store.submit('tenant',dict(operation_id='c'*32,conversation='b'*32,body='Synthetic queued follow-up',consent_version=1,files=[]))
        self.publisher.publish();self.publisher.publish()
        self.assertFalse(any(op=='create_issue' for op,_ in self.calls))
        self.assertEqual('uncertain',self.store.pending()[0]['state'])

    def follow_up(self,operation='c',**changes):
        return self.store.submit('tenant',{'operation_id':operation*32,'conversation':'b'*32,'body':'Synthetic follow-up','consent_version':1,'files':[],**changes})

    def test_title_contains_only_the_server_supplied_author_id(self):
        self.store.db.execute('DELETE FROM jobs');self.store.db.commit()
        user_id='10000000-0000-4000-8000-000000000001'
        self.follow_up(user_id=user_id)
        self.publisher.publish()
        title=[d['title'] for op,d in self.calls if op=='create_issue'][0]
        self.assertIn('user_id: '+user_id,title)
        self.assertNotIn('tenant',title);self.assertNotIn('b'*32,title)

    def test_deleted_issue_replaced_and_later_messages_and_replies_use_new_route(self):
        self.publisher.publish();self.follow_up()
        def broker(operation,**data):
            if operation=='issue':return dict(exists=data['issue']!=17)
            if operation=='create_issue':self.calls.append((operation,data));return dict(issue=42)
            return self.broker(operation,**data)
        self.publisher.broker=broker;self.publisher.publish()
        self.follow_up('d');self.publisher.publish()
        self.assertEqual([17,42],[r[0] for r in self.store.db.execute("SELECT issue FROM jobs WHERE state='published' AND comment IS NULL ORDER BY id")])
        self.assertEqual(42,[d['issue'] for op,d in self.calls if op=='create_comment'][-1])
        self.assertFalse(self.store.reply(17,105,'Synthetic obsolete reply'))
        self.assertTrue(self.store.reply(42,106,'Synthetic new reply'))
        self.assertEqual(['Synthetic new reply'],[r['body'] for r in self.store.replies('tenant',0)])

    def test_issue_lookup_outage_keeps_pending_job_and_original_route(self):
        self.publisher.publish();self.follow_up()
        def broker(operation,**data):
            if operation=='issue':raise RuntimeError('Synthetic outage')
            return self.broker(operation,**data)
        self.publisher.broker=broker
        with self.assertRaises(RuntimeError):self.publisher.publish()
        self.assertEqual('pending',self.store.pending()[0]['state'])
        self.assertEqual(17,self.store.pending()[0]['existing_issue'])
        self.assertEqual(1,len([1 for op,_ in self.calls if op=='create_issue']))

    def test_lost_comment_response_then_deletion_survives_worker_restart(self):
        self.publisher.publish();self.follow_up()
        def lost(operation,**data):
            if operation=='create_comment':raise RuntimeError('Synthetic lost response')
            return self.broker(operation,**data)
        self.publisher.broker=lost
        with self.assertRaises(RuntimeError):self.publisher.publish()
        self.store.db.close();self.store=Store(Path(self.tmp.name))
        def recovered(operation,**data):
            if operation=='issue':return dict(exists=False)
            if operation=='create_issue':self.calls.append((operation,data));return dict(issue=42)
            return self.broker(operation,**data)
        self.publisher=Publisher(self.store,recovered)
        self.publisher.publish();self.publisher.publish();self.publisher.publish()
        self.assertEqual([],self.store.pending())
        self.assertEqual(42,self.store.db.execute('SELECT issue FROM conversations').fetchone()[0])
        self.assertEqual(2,len([1 for op,_ in self.calls if op=='create_issue']))

    def test_lost_comment_response_on_live_issue_never_creates_replacement(self):
        self.publisher.publish();self.follow_up()
        def broker(operation,**data):
            if operation=='create_comment':raise RuntimeError('Synthetic ambiguous failure')
            return self.broker(operation,**data)
        self.publisher.broker=broker
        with self.assertRaises(RuntimeError):self.publisher.publish()
        self.publisher.publish();self.publisher.publish()
        self.assertEqual('uncertain',self.store.pending()[0]['state'])
        self.assertEqual(1,len([1 for op,_ in self.calls if op=='create_issue']))

    def test_closed_issue_is_not_treated_as_deleted(self):
        self.publisher.publish();self.follow_up()
        def broker(operation,**data):
            if operation=='issue':return dict(exists=True,state='closed')
            return self.broker(operation,**data)
        self.publisher.broker=broker;self.publisher.publish()
        self.assertEqual(1,len([1 for op,_ in self.calls if op=='create_issue']))
        self.assertEqual(17,[d['issue'] for op,d in self.calls if op=='create_comment'][-1])

    def test_delete_between_lookup_and_post_requeues_without_losing_file(self):
        import hashlib
        from support_gateway.broker import IssueMissing
        self.publisher.publish()
        content=b'Synthetic attachment';blob=self.store.blob('tenant','c'*32,0);blob.write_bytes(content)
        self.follow_up(files=[dict(name='synthetic.txt',size=len(content),sha256=hashlib.sha256(content).hexdigest())])
        lookups=0
        def broker(operation,**data):
            nonlocal lookups
            if operation=='issue':lookups+=1;return dict(exists=lookups==1)
            if operation=='create_comment':raise IssueMissing()
            if operation=='asset_release':return dict(id=1)
            if operation=='upload_asset':return dict(url='https://example.invalid/synthetic.txt')
            if operation=='create_issue':self.calls.append((operation,data));return dict(issue=42)
            return self.broker(operation,**data)
        self.publisher.broker=broker;self.publisher.publish()
        self.assertTrue(blob.exists());self.assertEqual('pending',self.store.pending()[0]['state'])
        self.publisher.publish();self.publisher.publish()
        self.assertFalse(blob.exists());self.assertEqual([],self.store.pending())
        self.assertEqual(2,len([1 for op,_ in self.calls if op=='create_issue']))

    def test_legacy_uncertain_comment_recovers_title_from_new_signed_message(self):
        self.publisher.publish();job=self.follow_up()
        self.store.publishing(job)  # Existing pre-upgrade journals did not store the POST target.
        user_id='10000000-0000-4000-8000-000000000001'
        self.follow_up('d',user_id=user_id)
        def broker(operation,**data):
            if operation=='issue':return dict(exists=data['issue']!=17)
            if operation=='create_issue':self.calls.append((operation,data));return dict(issue=42)
            return self.broker(operation,**data)
        self.publisher.broker=broker
        self.publisher.publish();self.publisher.publish();self.publisher.publish()
        self.assertEqual([],self.store.pending())
        self.assertIn('user_id: '+user_id,[d['title'] for op,d in self.calls if op=='create_issue'][-1])
    def test_unknown_or_forwarded_reply_is_not_imported(self):
        self.publisher.publish()
        rows=[dict(id=101,issue=17,body='Synthetic outsider',login='outsider'),dict(id=102,issue=17,body='Synthetic staff',login='staff'),dict(id=103,issue=99,body='Unmapped',login='staff')]
        def broker(operation,**data):
            if operation=='comments':return rows if data['page']==1 else []
            if operation=='permission':return dict(permission='write' if data['login']=='staff' else 'read')
            return self.broker(operation,**data)
        self.publisher.broker=broker;self.publisher.receive()
        self.assertEqual(['Synthetic staff'],[r['body'] for r in self.store.replies('tenant',0)])

if __name__=='__main__':unittest.main()
