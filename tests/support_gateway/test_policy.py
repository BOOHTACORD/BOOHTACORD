"""Public support must never become an arbitrary GitHub credential proxy."""
import unittest
from support_gateway.policy import publication, reply_allowed, broker_request

class PolicyTests(unittest.TestCase):
    def message(self, **changes):
        return {'operation_id':'a'*32,'conversation':'b'*32,'body':'Synthetic support message',
                'consent_version':1,'files':[],**changes}

    def test_only_explicit_current_consent_allows_publication(self):
        for consent in (None,False,0,2):
            with self.subTest(consent=consent),self.assertRaises(ValueError):publication(self.message(consent_version=consent),1)
        self.assertEqual('Synthetic support message',publication(self.message(),1)['body'])

    def test_no_private_metadata_or_unknown_fields_in_publication(self):
        for name in ('session_token','dm_id','hostname','installation_id','author','history'):
            with self.subTest(field=name),self.assertRaises(ValueError):publication(self.message(**{name:'private-canary'}),1)

    def test_author_id_is_a_canonical_nonzero_uuid_only(self):
        user_id='10000000-0000-4000-8000-000000000001'
        self.assertEqual(user_id,publication(self.message(user_id=user_id),1)['user_id'])
        for value in (None,False,'','private-canary','0'*32,'00000000-0000-0000-0000-000000000000',user_id+'\nmalicious title'):
            with self.subTest(value=value),self.assertRaises(ValueError):publication(self.message(user_id=value),1)

    def test_issue_lookup_is_repository_scoped_and_bounded(self):
        self.assertEqual(17,broker_request(dict(operation='issue',issue=17))['issue'])
        for value in (0,-1,True,'17'):
            with self.subTest(value=value),self.assertRaises(ValueError):broker_request(dict(operation='issue',issue=value))

    def test_message_and_file_bounds_are_enforced_before_storage(self):
        for changes in ({'body':'x'*8001},{'body':'bad\x00'},{'files':[{}]*11},{'operation_id':'../../credentials'}):
            with self.subTest(changes=str(changes)[:50]),self.assertRaises(ValueError):publication(self.message(**changes),1)

    def test_no_arbitrary_repo_url_command_or_path_in_broker(self):
        for request in ({'operation':'shell','command':'private-canary'},
                        {'operation':'create_issue','repo':'other/repo','body':'x'},
                        {'operation':'upload_asset','path':'/root/.config/gh/hosts.yml'}):
            with self.subTest(request=request),self.assertRaises(ValueError):broker_request(request)

    def test_read_only_outsiders_and_own_forwarded_comments_never_become_support_replies(self):
        self.assertFalse(reply_allowed('read',False))
        self.assertFalse(reply_allowed('write',True))
        self.assertFalse(reply_allowed('admin',True))
        self.assertTrue(reply_allowed('write',False))
        self.assertTrue(reply_allowed('admin',False))

if __name__=='__main__':unittest.main()
