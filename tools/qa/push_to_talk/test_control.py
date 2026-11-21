import urllib.error
import urllib.request
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from .control import media_control


class MediaControlTests(unittest.TestCase):
    def request(self, control, path, token=None):
        request = urllib.request.Request(control['base']+path, method='POST', data=b'',
            headers={'Authorization':'Bearer '+(token or '')})
        try:
            with urllib.request.urlopen(request, timeout=3) as response: return response.status
        except urllib.error.HTTPError as error: return error.code

    def test_owned_sfu_only_and_nonce_required(self):
        owner = 'qa-client-'+'a'*16
        stack = SimpleNamespace(owner=owner, resources=[('container', owner+'-sfu')])
        with patch('tools.qa.push_to_talk.control.output', return_value=owner), patch('tools.qa.push_to_talk.control.run') as run:
            with media_control(stack) as control:
                self.assertEqual(self.request(control,'/stop-sfu','wrong'),403)
                self.assertEqual(self.request(control,'/arbitrary',control['token']),404)
                run.assert_not_called()
                self.assertEqual(self.request(control,'/stop-sfu',control['token']),204)
                self.assertEqual(run.call_args.args,('docker','stop','--time=0',owner+'-sfu'))
                self.assertEqual(self.request(control,'/start-sfu',control['token']),204)
                self.assertEqual(run.call_args.args,('docker','start',owner+'-sfu'))

    def test_foreign_label_never_executes_a_media_action(self):
        owner = 'qa-client-'+'a'*16
        stack = SimpleNamespace(owner=owner, resources=[('container', owner+'-sfu')])
        with patch('tools.qa.push_to_talk.control.output', return_value='foreign'), patch('tools.qa.push_to_talk.control.run') as run:
            with media_control(stack) as control:
                self.assertEqual(self.request(control,'/stop-sfu',control['token']),500)
                run.assert_not_called()
