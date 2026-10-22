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
